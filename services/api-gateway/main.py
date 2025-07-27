"""
Tournament Management System API Gateway
Main entry point for all API requests with authentication, rate limiting, and service routing.
"""
import os
import logging
import time
import uuid
from typing import Dict, Any, Optional
from fastapi import FastAPI, Request, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse, Response
from fastapi.security import HTTPBearer
import httpx
import redis
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import uvicorn

# Import shared modules
import sys
sys.path.append('../shared')
from models import ApiResponse, ErrorDetail, HealthCheck
from auth import get_current_user, get_optional_user, AuthUser, RateLimiter, verify_api_key
from database import db_manager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
DEBUG = ENVIRONMENT == "development"
VERSION = "1.0.0"

# Service URLs
SERVICE_URLS = {
    "tournament": os.getenv("TOURNAMENT_API_URL", "http://tournament-api:8080"),
    "elo": os.getenv("ELO_SERVICE_URL", "http://elo-service:8080"),
    "leaderboard": os.getenv("LEADERBOARD_SERVICE_URL", "http://leaderboard-service:8080"),
    "review": os.getenv("REVIEW_WORKFLOW_URL", "http://review-workflow:8080"),
    "hash": os.getenv("HASH_VERIFICATION_URL", "http://hash-verification:8080"),
    "team": os.getenv("TEAM_MANAGEMENT_URL", "http://team-management:8080"),
    "match": os.getenv("MATCH_SCHEDULING_URL", "http://match-scheduling:8080"),
    "notification": os.getenv("NOTIFICATION_SERVICE_URL", "http://notification-service:8080"),
    "audit": os.getenv("AUDIT_SERVICE_URL", "http://audit-service:8080")
}

# Redis for rate limiting and caching
REDIS_URL = os.getenv("REDIS_URL", "redis://:redis_pass@localhost:6379/0")
redis_client = redis.from_url(REDIS_URL, decode_responses=True)

# Prometheus metrics
request_count = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
request_duration = Histogram('http_request_duration_seconds', 'HTTP request duration')
service_request_count = Counter('service_requests_total', 'Total service requests', ['service', 'status'])
service_request_duration = Histogram('service_request_duration_seconds', 'Service request duration', ['service'])

# Create FastAPI app
app = FastAPI(
    title="Tournament Management API Gateway",
    description="Central API gateway for tournament management system",
    version=VERSION,
    docs_url="/docs" if DEBUG else None,
    redoc_url="/redoc" if DEBUG else None,
    openapi_url="/openapi.json" if DEBUG else None
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if DEBUG else ["https://yourdomain.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Rate-Limit-Remaining", "X-Rate-Limit-Reset"]
)

# Trusted host middleware for production
if not DEBUG:
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=["yourdomain.com", "*.yourdomain.com"]
    )

# HTTP client for service communication
http_client = httpx.AsyncClient(timeout=30.0)


@app.middleware("http")
async def request_middleware(request: Request, call_next):
    """Request middleware for logging, metrics, and rate limiting."""
    start_time = time.time()
    request_id = str(uuid.uuid4())
    
    # Add request ID to headers
    request.state.request_id = request_id
    
    # Rate limiting
    client_ip = request.client.host
    user_agent = request.headers.get("user-agent", "unknown")
    rate_limit_key = f"{client_ip}:{user_agent}"
    
    # Check rate limit (100 requests per minute by default)
    rate_limit = 100
    window = 60
    
    if not RateLimiter.check_rate_limit(rate_limit_key, rate_limit, window):
        rate_info = RateLimiter.get_rate_limit_info(rate_limit_key, rate_limit, window)
        response = JSONResponse(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            content={
                "success": False,
                "error": {
                    "code": "RATE_LIMIT_EXCEEDED",
                    "message": "Rate limit exceeded",
                    "details": rate_info
                },
                "request_id": request_id
            },
            headers={
                "X-Rate-Limit-Remaining": str(rate_info["remaining"]),
                "X-Rate-Limit-Reset": str(rate_info["reset_time"])
            }
        )
        request_count.labels(
            method=request.method, 
            endpoint=request.url.path, 
            status="429"
        ).inc()
        return response
    
    # Process request
    try:
        response = await call_next(request)
        
        # Add response headers
        response.headers["X-Request-ID"] = request_id
        response.headers["X-API-Version"] = VERSION
        
        # Update metrics
        duration = time.time() - start_time
        request_duration.observe(duration)
        request_count.labels(
            method=request.method,
            endpoint=request.url.path,
            status=str(response.status_code)
        ).inc()
        
        return response
        
    except Exception as e:
        logger.error(f"Request {request_id} failed: {e}")
        request_count.labels(
            method=request.method,
            endpoint=request.url.path,
            status="500"
        ).inc()
        
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "success": False,
                "error": {
                    "code": "INTERNAL_ERROR",
                    "message": "Internal server error",
                    "details": {"request_id": request_id}
                },
                "request_id": request_id
            }
        )


async def proxy_to_service(request: Request, service: str, path: str, user: Optional[AuthUser] = None):
    """Proxy request to microservice."""
    service_url = SERVICE_URLS.get(service)
    if not service_url:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Service '{service}' not found"
        )
    
    target_url = f"{service_url}/{path.lstrip('/')}"
    
    # Prepare headers
    headers = dict(request.headers)
    if user:
        headers["X-User-ID"] = user.user_id
        headers["X-User-Email"] = user.email
        headers["X-User-Role"] = user.role
    
    headers["X-Request-ID"] = request.state.request_id
    headers["X-Forwarded-For"] = request.client.host
    
    # Remove hop-by-hop headers
    hop_by_hop = ["connection", "keep-alive", "proxy-authenticate", 
                 "proxy-authorization", "te", "trailers", "transfer-encoding", "upgrade"]
    for header in hop_by_hop:
        headers.pop(header, None)
    
    start_time = time.time()
    
    try:
        # Get request body if present
        body = None
        if request.method in ["POST", "PUT", "PATCH"]:
            body = await request.body()
        
        # Make request to service
        response = await http_client.request(
            method=request.method,
            url=target_url,
            headers=headers,
            params=request.query_params,
            content=body
        )
        
        # Update metrics
        duration = time.time() - start_time
        service_request_duration.labels(service=service).observe(duration)
        service_request_count.labels(service=service, status=str(response.status_code)).inc()
        
        # Return response
        return JSONResponse(
            content=response.json() if response.content else None,
            status_code=response.status_code,
            headers=dict(response.headers)
        )
        
    except httpx.RequestError as e:
        logger.error(f"Service request failed: {e}")
        service_request_count.labels(service=service, status="error").inc()
        
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Service '{service}' unavailable"
        )


# Health check endpoint
@app.get("/health", response_model=HealthCheck)
async def health_check():
    """System health check."""
    services = {}
    
    # Check database
    try:
        services["database"] = await db_manager.health_check()
    except Exception:
        services["database"] = False
    
    # Check Redis
    try:
        redis_client.ping()
        services["redis"] = True
    except Exception:
        services["redis"] = False
    
    # Check microservices
    for service_name, service_url in SERVICE_URLS.items():
        try:
            response = await http_client.get(f"{service_url}/health", timeout=5.0)
            services[service_name] = response.status_code == 200
        except Exception:
            services[service_name] = False
    
    # Determine overall status
    all_healthy = all(services.values())
    status_text = "healthy" if all_healthy else "unhealthy"
    
    return HealthCheck(
        status=status_text,
        version=VERSION,
        environment=ENVIRONMENT,
        services=services
    )


# Metrics endpoint
@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


# Authentication endpoints
@app.post("/auth/login")
async def login(credentials: dict):
    """User login endpoint."""
    # For now, return a mock token - this would integrate with actual auth service
    from auth import TokenManager
    
    email = credentials.get("email")
    password = credentials.get("password")
    
    if not email or not password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email and password required"
        )
    
    # Mock user validation - replace with actual user service
    if email == "admin@tournament.com" and password == "admin123":
        token_data = {
            "sub": "admin-user-id",
            "email": email,
            "role": "admin"
        }
        access_token = TokenManager.create_access_token(token_data)
        refresh_token = TokenManager.create_refresh_token(token_data)
        
        return ApiResponse(
            success=True,
            data={
                "access_token": access_token,
                "refresh_token": refresh_token,
                "token_type": "bearer",
                "user": {
                    "id": "admin-user-id",
                    "email": email,
                    "role": "admin"
                }
            }
        )
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid credentials"
    )


@app.post("/auth/logout")
async def logout(current_user: AuthUser = Depends(get_current_user)):
    """User logout endpoint."""
    from auth import TokenManager, SessionManager
    
    # Blacklist current token and delete session
    # This would require access to the current token, which we'd need to pass through
    if current_user.session_id:
        SessionManager.delete_session(current_user.session_id)
    
    return ApiResponse(
        success=True,
        data={"message": "Successfully logged out"}
    )


# Tournament API routes
@app.api_route("/api/v1/tournaments/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def tournament_proxy(request: Request, path: str, user: AuthUser = Depends(get_optional_user)):
    """Proxy requests to tournament service."""
    return await proxy_to_service(request, "tournament", f"api/v1/tournaments/{path}", user)


@app.api_route("/api/v1/tournaments", methods=["GET", "POST"])
async def tournament_list_proxy(request: Request, user: AuthUser = Depends(get_optional_user)):
    """Proxy tournament list requests."""
    return await proxy_to_service(request, "tournament", "api/v1/tournaments", user)


# Team management routes
@app.api_route("/api/v1/teams/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def team_proxy(request: Request, path: str, user: AuthUser = Depends(get_optional_user)):
    """Proxy requests to team management service."""
    return await proxy_to_service(request, "team", f"api/v1/teams/{path}", user)


@app.api_route("/api/v1/teams", methods=["GET", "POST"])
async def team_list_proxy(request: Request, user: AuthUser = Depends(get_optional_user)):
    """Proxy team list requests."""
    return await proxy_to_service(request, "team", "api/v1/teams", user)


# Match scheduling routes
@app.api_route("/api/v1/matches/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def match_proxy(request: Request, path: str, user: AuthUser = Depends(get_optional_user)):
    """Proxy requests to match scheduling service."""
    return await proxy_to_service(request, "match", f"api/v1/matches/{path}", user)


@app.api_route("/api/v1/matches", methods=["GET", "POST"])
async def match_list_proxy(request: Request, user: AuthUser = Depends(get_optional_user)):
    """Proxy match list requests."""
    return await proxy_to_service(request, "match", "api/v1/matches", user)


# Leaderboard routes
@app.api_route("/api/v1/leaderboards/{path:path}", methods=["GET"])
async def leaderboard_proxy(request: Request, path: str):
    """Proxy requests to leaderboard service."""
    return await proxy_to_service(request, "leaderboard", f"api/v1/leaderboards/{path}")


@app.api_route("/api/v1/leaderboards", methods=["GET"])
async def leaderboard_list_proxy(request: Request):
    """Proxy leaderboard list requests."""
    return await proxy_to_service(request, "leaderboard", "api/v1/leaderboards")


# ELO rating routes
@app.api_route("/api/v1/elo/{path:path}", methods=["GET", "POST"])
async def elo_proxy(request: Request, path: str, user: AuthUser = Depends(get_optional_user)):
    """Proxy requests to ELO service."""
    return await proxy_to_service(request, "elo", f"api/v1/elo/{path}", user)


# Review workflow routes
@app.api_route("/api/v1/reviews/{path:path}", methods=["GET", "POST", "PUT", "PATCH"])
async def review_proxy(request: Request, path: str, user: AuthUser = Depends(get_current_user)):
    """Proxy requests to review workflow service."""
    return await proxy_to_service(request, "review", f"api/v1/reviews/{path}", user)


# Notification routes
@app.api_route("/api/v1/notifications/{path:path}", methods=["GET", "POST"])
async def notification_proxy(request: Request, path: str, user: AuthUser = Depends(get_optional_user)):
    """Proxy requests to notification service."""
    return await proxy_to_service(request, "notification", f"api/v1/notifications/{path}", user)


# Audit routes (admin only)
@app.api_route("/api/v1/audit/{path:path}", methods=["GET"])
async def audit_proxy(request: Request, path: str, user: AuthUser = Depends(get_current_user)):
    """Proxy requests to audit service."""
    if not user.has_permission("system:view_audit"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions"
        )
    return await proxy_to_service(request, "audit", f"api/v1/audit/{path}", user)


# WebSocket support for real-time updates
@app.websocket("/ws")
async def websocket_endpoint(websocket):
    """WebSocket endpoint for real-time updates."""
    await websocket.accept()
    # WebSocket implementation would go here
    # For now, just accept and close
    await websocket.close()


# Global exception handler
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Handle HTTP exceptions."""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": {
                "code": "HTTP_ERROR",
                "message": exc.detail
            },
            "request_id": getattr(request.state, "request_id", None)
        }
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle general exceptions."""
    logger.error(f"Unhandled exception: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "error": {
                "code": "INTERNAL_ERROR",
                "message": "Internal server error"
            },
            "request_id": getattr(request.state, "request_id", None)
        }
    )


# Startup and shutdown events
@app.on_event("startup")
async def startup_event():
    """Application startup."""
    logger.info(f"API Gateway starting up (version: {VERSION}, environment: {ENVIRONMENT})")
    
    # Test database connection
    try:
        db_healthy = await db_manager.health_check()
        logger.info(f"Database connection: {'healthy' if db_healthy else 'unhealthy'}")
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
    
    # Test Redis connection
    try:
        redis_client.ping()
        logger.info("Redis connection: healthy")
    except Exception as e:
        logger.error(f"Redis connection failed: {e}")


@app.on_event("shutdown")
async def shutdown_event():
    """Application shutdown."""
    logger.info("API Gateway shutting down")
    await http_client.aclose()


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        reload=DEBUG,
        log_level="info"
    ) 