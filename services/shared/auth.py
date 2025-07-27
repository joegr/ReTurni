"""
Shared authentication and authorization utilities for tournament microservices.
Provides JWT token handling, role-based access control, and security middleware.
"""
import os
import jwt
import logging
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from fastapi import HTTPException, status, Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from passlib.context import CryptContext
import redis
import json

logger = logging.getLogger(__name__)

# Configuration
JWT_SECRET = os.getenv("JWT_SECRET", "your-super-secret-jwt-key-change-in-production")
JWT_ALGORITHM = "HS256"
JWT_ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("JWT_ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
JWT_REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("JWT_REFRESH_TOKEN_EXPIRE_DAYS", "7"))

# Redis for token blacklisting and session management
REDIS_URL = os.getenv("REDIS_URL", "redis://:redis_pass@localhost:6379/0")
redis_client = redis.from_url(REDIS_URL, decode_responses=True)

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# JWT Bearer scheme
security = HTTPBearer()


class UserRole:
    """User role constants."""
    ADMIN = "admin"
    TOURNAMENT_MANAGER = "tournament_manager"
    REFEREE = "referee"
    TEAM_CAPTAIN = "team_captain"
    PLAYER = "player"
    VIEWER = "viewer"


class Permission:
    """Permission constants."""
    # Tournament permissions
    CREATE_TOURNAMENT = "tournament:create"
    UPDATE_TOURNAMENT = "tournament:update"
    DELETE_TOURNAMENT = "tournament:delete"
    VIEW_TOURNAMENT = "tournament:view"
    DEPLOY_TOURNAMENT = "tournament:deploy"
    PAUSE_TOURNAMENT = "tournament:pause"
    
    # Team permissions
    APPROVE_TEAM = "team:approve"
    REJECT_TEAM = "team:reject"
    VIEW_TEAM = "team:view"
    UPDATE_TEAM = "team:update"
    DELETE_TEAM = "team:delete"
    
    # Match permissions
    SCHEDULE_MATCH = "match:schedule"
    UPDATE_MATCH = "match:update"
    SUBMIT_RESULT = "match:submit_result"
    APPROVE_RESULT = "match:approve_result"
    REJECT_RESULT = "match:reject_result"
    
    # System permissions
    VIEW_AUDIT_LOGS = "system:view_audit"
    MANAGE_USERS = "system:manage_users"
    SYSTEM_CONFIG = "system:config"
    VIEW_METRICS = "system:metrics"


# Role-based permissions mapping
ROLE_PERMISSIONS = {
    UserRole.ADMIN: [
        Permission.CREATE_TOURNAMENT, Permission.UPDATE_TOURNAMENT, Permission.DELETE_TOURNAMENT,
        Permission.VIEW_TOURNAMENT, Permission.DEPLOY_TOURNAMENT, Permission.PAUSE_TOURNAMENT,
        Permission.APPROVE_TEAM, Permission.REJECT_TEAM, Permission.VIEW_TEAM,
        Permission.UPDATE_TEAM, Permission.DELETE_TEAM,
        Permission.SCHEDULE_MATCH, Permission.UPDATE_MATCH, Permission.SUBMIT_RESULT,
        Permission.APPROVE_RESULT, Permission.REJECT_RESULT,
        Permission.VIEW_AUDIT_LOGS, Permission.MANAGE_USERS, Permission.SYSTEM_CONFIG,
        Permission.VIEW_METRICS
    ],
    UserRole.TOURNAMENT_MANAGER: [
        Permission.CREATE_TOURNAMENT, Permission.UPDATE_TOURNAMENT, Permission.VIEW_TOURNAMENT,
        Permission.DEPLOY_TOURNAMENT, Permission.PAUSE_TOURNAMENT,
        Permission.APPROVE_TEAM, Permission.REJECT_TEAM, Permission.VIEW_TEAM,
        Permission.SCHEDULE_MATCH, Permission.UPDATE_MATCH,
        Permission.APPROVE_RESULT, Permission.REJECT_RESULT,
        Permission.VIEW_AUDIT_LOGS
    ],
    UserRole.REFEREE: [
        Permission.VIEW_TOURNAMENT, Permission.VIEW_TEAM,
        Permission.SUBMIT_RESULT, Permission.UPDATE_MATCH
    ],
    UserRole.TEAM_CAPTAIN: [
        Permission.VIEW_TOURNAMENT, Permission.VIEW_TEAM, Permission.UPDATE_TEAM
    ],
    UserRole.PLAYER: [
        Permission.VIEW_TOURNAMENT, Permission.VIEW_TEAM
    ],
    UserRole.VIEWER: [
        Permission.VIEW_TOURNAMENT
    ]
}


class AuthUser:
    """Authenticated user model."""
    
    def __init__(self, user_id: str, email: str, role: str, permissions: List[str], 
                 session_id: str = None, **kwargs):
        self.user_id = user_id
        self.email = email
        self.role = role
        self.permissions = permissions
        self.session_id = session_id
        self.extra_data = kwargs
    
    def has_permission(self, permission: str) -> bool:
        """Check if user has specific permission."""
        return permission in self.permissions
    
    def has_role(self, role: str) -> bool:
        """Check if user has specific role."""
        return self.role == role
    
    def has_any_role(self, roles: List[str]) -> bool:
        """Check if user has any of the specified roles."""
        return self.role in roles


class TokenManager:
    """JWT token management."""
    
    @staticmethod
    def create_access_token(data: Dict[str, Any], expires_delta: timedelta = None) -> str:
        """Create JWT access token."""
        to_encode = data.copy()
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
        
        to_encode.update({
            "exp": expire,
            "iat": datetime.utcnow(),
            "type": "access"
        })
        
        encoded_jwt = jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)
        return encoded_jwt
    
    @staticmethod
    def create_refresh_token(data: Dict[str, Any]) -> str:
        """Create JWT refresh token."""
        to_encode = data.copy()
        expire = datetime.utcnow() + timedelta(days=JWT_REFRESH_TOKEN_EXPIRE_DAYS)
        
        to_encode.update({
            "exp": expire,
            "iat": datetime.utcnow(),
            "type": "refresh"
        })
        
        encoded_jwt = jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)
        return encoded_jwt
    
    @staticmethod
    def verify_token(token: str) -> Dict[str, Any]:
        """Verify and decode JWT token."""
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
            return payload
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired"
            )
        except jwt.InvalidTokenError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token"
            )
    
    @staticmethod
    def blacklist_token(token: str, expires_in: int = None):
        """Add token to blacklist."""
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
            jti = payload.get("jti") or token[:16]  # Use jti or token prefix
            exp = payload.get("exp")
            
            if exp:
                ttl = exp - int(datetime.utcnow().timestamp())
                if ttl > 0:
                    redis_client.setex(f"blacklist:{jti}", ttl, "1")
            else:
                redis_client.setex(f"blacklist:{jti}", expires_in or 3600, "1")
                
        except Exception as e:
            logger.error(f"Failed to blacklist token: {e}")
    
    @staticmethod
    def is_token_blacklisted(token: str) -> bool:
        """Check if token is blacklisted."""
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM], 
                              options={"verify_exp": False})
            jti = payload.get("jti") or token[:16]
            return redis_client.exists(f"blacklist:{jti}")
        except Exception:
            return True  # Treat invalid tokens as blacklisted


class PasswordManager:
    """Password hashing and verification."""
    
    @staticmethod
    def hash_password(password: str) -> str:
        """Hash password using bcrypt."""
        return pwd_context.hash(password)
    
    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        """Verify password against hash."""
        return pwd_context.verify(plain_password, hashed_password)


class SessionManager:
    """User session management."""
    
    @staticmethod
    def create_session(user_id: str, session_data: Dict[str, Any]) -> str:
        """Create user session."""
        import uuid
        session_id = str(uuid.uuid4())
        session_key = f"session:{session_id}"
        
        session_data.update({
            "user_id": user_id,
            "created_at": datetime.utcnow().isoformat(),
            "last_activity": datetime.utcnow().isoformat()
        })
        
        redis_client.setex(
            session_key, 
            timedelta(hours=24).total_seconds(), 
            json.dumps(session_data)
        )
        
        return session_id
    
    @staticmethod
    def get_session(session_id: str) -> Optional[Dict[str, Any]]:
        """Get session data."""
        session_key = f"session:{session_id}"
        session_data = redis_client.get(session_key)
        
        if session_data:
            data = json.loads(session_data)
            # Update last activity
            data["last_activity"] = datetime.utcnow().isoformat()
            redis_client.setex(session_key, timedelta(hours=24).total_seconds(), 
                             json.dumps(data))
            return data
        
        return None
    
    @staticmethod
    def delete_session(session_id: str):
        """Delete user session."""
        session_key = f"session:{session_id}"
        redis_client.delete(session_key)


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> AuthUser:
    """Get current authenticated user from JWT token."""
    token = credentials.credentials
    
    # Check if token is blacklisted
    if TokenManager.is_token_blacklisted(token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has been revoked"
        )
    
    # Verify token
    payload = TokenManager.verify_token(token)
    
    # Check token type
    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type"
        )
    
    # Extract user information
    user_id = payload.get("sub")
    email = payload.get("email")
    role = payload.get("role")
    session_id = payload.get("session_id")
    
    if not user_id or not email or not role:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload"
        )
    
    # Get permissions for role
    permissions = ROLE_PERMISSIONS.get(role, [])
    
    # Verify session if present
    if session_id:
        session_data = SessionManager.get_session(session_id)
        if not session_data or session_data.get("user_id") != user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid session"
            )
    
    return AuthUser(
        user_id=user_id,
        email=email,
        role=role,
        permissions=permissions,
        session_id=session_id,
        **{k: v for k, v in payload.items() if k not in ["sub", "email", "role", "session_id", "exp", "iat", "type"]}
    )


def require_permission(permission: str):
    """Decorator to require specific permission."""
    def decorator(current_user: AuthUser = Depends(get_current_user)):
        if not current_user.has_permission(permission):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permission '{permission}' required"
            )
        return current_user
    return decorator


def require_role(role: str):
    """Decorator to require specific role."""
    def decorator(current_user: AuthUser = Depends(get_current_user)):
        if not current_user.has_role(role):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Role '{role}' required"
            )
        return current_user
    return decorator


def require_any_role(roles: List[str]):
    """Decorator to require any of the specified roles."""
    def decorator(current_user: AuthUser = Depends(get_current_user)):
        if not current_user.has_any_role(roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"One of roles {roles} required"
            )
        return current_user
    return decorator


def get_optional_user(credentials: Optional[HTTPAuthorizationCredentials] = Depends(HTTPBearer(auto_error=False))) -> Optional[AuthUser]:
    """Get current user if authenticated, otherwise None."""
    if not credentials:
        return None
    
    try:
        return get_current_user(credentials)
    except HTTPException:
        return None


class RateLimiter:
    """Rate limiting implementation."""
    
    @staticmethod
    def check_rate_limit(key: str, limit: int, window: int) -> bool:
        """Check rate limit for a given key."""
        current_time = int(datetime.utcnow().timestamp())
        window_start = current_time - window
        
        # Clean old entries
        redis_client.zremrangebyscore(f"rate_limit:{key}", 0, window_start)
        
        # Count current requests
        current_requests = redis_client.zcard(f"rate_limit:{key}")
        
        if current_requests >= limit:
            return False
        
        # Add current request
        redis_client.zadd(f"rate_limit:{key}", {str(current_time): current_time})
        redis_client.expire(f"rate_limit:{key}", window)
        
        return True
    
    @staticmethod
    def get_rate_limit_info(key: str, limit: int, window: int) -> Dict[str, Any]:
        """Get rate limit information."""
        current_time = int(datetime.utcnow().timestamp())
        window_start = current_time - window
        
        # Clean old entries
        redis_client.zremrangebyscore(f"rate_limit:{key}", 0, window_start)
        
        # Count current requests
        current_requests = redis_client.zcard(f"rate_limit:{key}")
        
        return {
            "limit": limit,
            "remaining": max(0, limit - current_requests),
            "reset_time": current_time + window,
            "window": window
        }


def create_api_key(user_id: str, name: str, permissions: List[str] = None) -> str:
    """Create API key for service-to-service communication."""
    import secrets
    
    api_key = secrets.token_urlsafe(32)
    key_data = {
        "user_id": user_id,
        "name": name,
        "permissions": permissions or [],
        "created_at": datetime.utcnow().isoformat(),
        "active": True
    }
    
    redis_client.setex(f"api_key:{api_key}", timedelta(days=365).total_seconds(), 
                      json.dumps(key_data))
    
    return api_key


def verify_api_key(api_key: str) -> Optional[Dict[str, Any]]:
    """Verify API key and return key data."""
    key_data = redis_client.get(f"api_key:{api_key}")
    if key_data:
        data = json.loads(key_data)
        if data.get("active", False):
            return data
    return None


# Export commonly used items
__all__ = [
    "AuthUser", "UserRole", "Permission", "TokenManager", "PasswordManager", 
    "SessionManager", "RateLimiter", "get_current_user", "get_optional_user",
    "require_permission", "require_role", "require_any_role",
    "create_api_key", "verify_api_key"
] 