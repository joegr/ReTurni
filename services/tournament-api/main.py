"""
Tournament API Service
Handles tournament CRUD operations, deployment management, and configuration.
"""
import os
import logging
import uuid
from datetime import datetime
from typing import List, Optional, Dict, Any
from fastapi import FastAPI, HTTPException, Depends, status, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, desc
import asyncio
import httpx

# Import shared modules
import sys
sys.path.append('../shared')
from models import (
    Tournament, TournamentCreate, TournamentUpdate, TournamentStatus, TournamentType,
    ApiResponse, HealthCheck, PaginationParams, PaginatedResponse
)
from database import get_db, generate_hash, with_transaction
from auth import get_current_user, get_optional_user, AuthUser, require_permission, Permission

# Import local modules
from database_models import TournamentModel, TournamentTeamModel
from services.tournament_service import TournamentService
from services.kubernetes_service import KubernetesService

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
DEBUG = ENVIRONMENT == "development"
VERSION = "1.0.0"

# Service URLs for inter-service communication
ELO_SERVICE_URL = os.getenv("ELO_SERVICE_URL", "http://elo-service:8080")
LEADERBOARD_SERVICE_URL = os.getenv("LEADERBOARD_SERVICE_URL", "http://leaderboard-service:8080")
NOTIFICATION_SERVICE_URL = os.getenv("NOTIFICATION_SERVICE_URL", "http://notification-service:8080")
AUDIT_SERVICE_URL = os.getenv("AUDIT_SERVICE_URL", "http://audit-service:8080")

# Create FastAPI app
app = FastAPI(
    title="Tournament API Service",
    description="Tournament management and deployment service",
    version=VERSION,
    docs_url="/docs" if DEBUG else None,
    redoc_url="/redoc" if DEBUG else None,
    openapi_url="/openapi.json" if DEBUG else None
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if DEBUG else [],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

# HTTP client for service communication
http_client = httpx.AsyncClient(timeout=30.0)

# Initialize services
tournament_service = TournamentService()
k8s_service = KubernetesService()


@app.get("/health", response_model=HealthCheck)
async def health_check():
    """Health check endpoint."""
    return HealthCheck(
        status="healthy",
        version=VERSION,
        environment=ENVIRONMENT,
        services={
            "database": True,  # Would check actual DB connection
            "kubernetes": await k8s_service.health_check()
        }
    )


@app.get("/api/v1/tournaments", response_model=PaginatedResponse)
async def list_tournaments(
    pagination: PaginationParams = Depends(),
    status_filter: Optional[TournamentStatus] = None,
    tournament_type: Optional[TournamentType] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: Optional[AuthUser] = Depends(get_optional_user)
):
    """List tournaments with filtering and pagination."""
    try:
        query = db.query(TournamentModel)
        
        # Apply filters
        if status_filter:
            query = query.filter(TournamentModel.status == status_filter.value)
        
        if tournament_type:
            query = query.filter(TournamentModel.tournament_type == tournament_type.value)
        
        if search:
            query = query.filter(
                or_(
                    TournamentModel.name.ilike(f"%{search}%"),
                    TournamentModel.description.ilike(f"%{search}%")
                )
            )
        
        # Apply sorting
        if pagination.sort_by:
            if pagination.sort_order == "desc":
                query = query.order_by(desc(getattr(TournamentModel, pagination.sort_by)))
            else:
                query = query.order_by(getattr(TournamentModel, pagination.sort_by))
        else:
            query = query.order_by(desc(TournamentModel.created_at))
        
        # Get total count
        total = query.count()
        
        # Apply pagination
        tournaments = query.offset((pagination.page - 1) * pagination.size).limit(pagination.size).all()
        
        # Convert to response models
        tournament_responses = []
        for tournament in tournaments:
            tournament_data = Tournament(
                id=tournament.id,
                name=tournament.name,
                description=tournament.description,
                tournament_type=TournamentType(tournament.tournament_type),
                status=TournamentStatus(tournament.status),
                start_date=tournament.start_date,
                end_date=tournament.end_date,
                max_teams=tournament.max_teams,
                current_teams=tournament.current_teams,
                config=tournament.config,
                created_at=tournament.created_at,
                updated_at=tournament.updated_at,
                created_by=tournament.created_by,
                hash=tournament.hash
            )
            tournament_responses.append(tournament_data)
        
        pages = (total + pagination.size - 1) // pagination.size
        
        return PaginatedResponse(
            items=tournament_responses,
            total=total,
            page=pagination.page,
            size=pagination.size,
            pages=pages
        )
        
    except Exception as e:
        logger.error(f"Failed to list tournaments: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve tournaments"
        )


@app.get("/api/v1/tournaments/{tournament_id}", response_model=Tournament)
async def get_tournament(
    tournament_id: str,
    db: Session = Depends(get_db),
    current_user: Optional[AuthUser] = Depends(get_optional_user)
):
    """Get tournament by ID."""
    try:
        tournament = db.query(TournamentModel).filter(TournamentModel.id == tournament_id).first()
        
        if not tournament:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Tournament not found"
            )
        
        return Tournament(
            id=tournament.id,
            name=tournament.name,
            description=tournament.description,
            tournament_type=TournamentType(tournament.tournament_type),
            status=TournamentStatus(tournament.status),
            start_date=tournament.start_date,
            end_date=tournament.end_date,
            max_teams=tournament.max_teams,
            current_teams=tournament.current_teams,
            config=tournament.config,
            created_at=tournament.created_at,
            updated_at=tournament.updated_at,
            created_by=tournament.created_by,
            hash=tournament.hash
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get tournament {tournament_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve tournament"
        )


@app.post("/api/v1/tournaments", response_model=Tournament, status_code=status.HTTP_201_CREATED)
async def create_tournament(
    tournament_data: TournamentCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: AuthUser = Depends(require_permission(Permission.CREATE_TOURNAMENT))
):
    """Create a new tournament."""
    try:
        with with_transaction(db):
            # Generate tournament ID
            tournament_id = str(uuid.uuid4())
            
            # Create tournament record
            tournament_dict = tournament_data.dict()
            tournament_dict['id'] = tournament_id
            tournament_dict['created_by'] = current_user.user_id
            tournament_dict['status'] = TournamentStatus.DEPLOYING.value
            tournament_dict['current_teams'] = 0
            tournament_dict['created_at'] = datetime.utcnow()
            tournament_dict['updated_at'] = datetime.utcnow()
            
            # Generate hash for integrity
            hash_data = f"{tournament_dict['name']}{tournament_dict['start_date']}{tournament_dict['created_by']}"
            tournament_dict['hash'] = generate_hash(hash_data)
            
            tournament = TournamentModel(**tournament_dict)
            db.add(tournament)
            db.flush()  # Get the ID
            
            # Start deployment process in background
            background_tasks.add_task(
                deploy_tournament_infrastructure,
                tournament_id,
                tournament_data.dict(),
                current_user.user_id
            )
            
            # Send audit log
            background_tasks.add_task(
                send_audit_log,
                "tournament_create",
                current_user.user_id,
                current_user.email,
                "tournament",
                tournament_id,
                {"tournament_name": tournament_data.name}
            )
            
            return Tournament(
                id=tournament.id,
                name=tournament.name,
                description=tournament.description,
                tournament_type=TournamentType(tournament.tournament_type),
                status=TournamentStatus(tournament.status),
                start_date=tournament.start_date,
                end_date=tournament.end_date,
                max_teams=tournament.max_teams,
                current_teams=tournament.current_teams,
                config=tournament.config,
                created_at=tournament.created_at,
                updated_at=tournament.updated_at,
                created_by=tournament.created_by,
                hash=tournament.hash
            )
            
    except Exception as e:
        logger.error(f"Failed to create tournament: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create tournament"
        )


@app.put("/api/v1/tournaments/{tournament_id}", response_model=Tournament)
async def update_tournament(
    tournament_id: str,
    tournament_update: TournamentUpdate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: AuthUser = Depends(require_permission(Permission.UPDATE_TOURNAMENT))
):
    """Update tournament."""
    try:
        with with_transaction(db):
            tournament = db.query(TournamentModel).filter(TournamentModel.id == tournament_id).first()
            
            if not tournament:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Tournament not found"
                )
            
            # Store old values for audit
            old_values = {
                "name": tournament.name,
                "description": tournament.description,
                "status": tournament.status,
                "end_date": tournament.end_date.isoformat() if tournament.end_date else None,
                "config": tournament.config
            }
            
            # Update fields
            update_data = tournament_update.dict(exclude_unset=True)
            for field, value in update_data.items():
                if field == "config" and value:
                    setattr(tournament, field, value.dict())
                else:
                    setattr(tournament, field, value)
            
            tournament.updated_at = datetime.utcnow()
            
            # Update hash
            hash_data = f"{tournament.name}{tournament.start_date}{tournament.created_by}"
            tournament.hash = generate_hash(hash_data)
            
            # Send audit log
            new_values = {
                "name": tournament.name,
                "description": tournament.description,
                "status": tournament.status,
                "end_date": tournament.end_date.isoformat() if tournament.end_date else None,
                "config": tournament.config
            }
            
            background_tasks.add_task(
                send_audit_log,
                "tournament_update",
                current_user.user_id,
                current_user.email,
                "tournament",
                tournament_id,
                {"old_values": old_values, "new_values": new_values}
            )
            
            return Tournament(
                id=tournament.id,
                name=tournament.name,
                description=tournament.description,
                tournament_type=TournamentType(tournament.tournament_type),
                status=TournamentStatus(tournament.status),
                start_date=tournament.start_date,
                end_date=tournament.end_date,
                max_teams=tournament.max_teams,
                current_teams=tournament.current_teams,
                config=tournament.config,
                created_at=tournament.created_at,
                updated_at=tournament.updated_at,
                created_by=tournament.created_by,
                hash=tournament.hash
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update tournament {tournament_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update tournament"
        )


@app.post("/api/v1/tournaments/{tournament_id}/deploy")
async def deploy_tournament(
    tournament_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: AuthUser = Depends(require_permission(Permission.DEPLOY_TOURNAMENT))
):
    """Deploy tournament infrastructure."""
    try:
        tournament = db.query(TournamentModel).filter(TournamentModel.id == tournament_id).first()
        
        if not tournament:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Tournament not found"
            )
        
        if tournament.status != TournamentStatus.DEPLOYING.value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Tournament is not in deploying status"
            )
        
        # Start deployment
        background_tasks.add_task(
            deploy_tournament_infrastructure,
            tournament_id,
            tournament.__dict__,
            current_user.user_id
        )
        
        return ApiResponse(
            success=True,
            data={"message": "Tournament deployment started", "tournament_id": tournament_id}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to deploy tournament {tournament_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to deploy tournament"
        )


@app.post("/api/v1/tournaments/{tournament_id}/pause")
async def pause_tournament(
    tournament_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: AuthUser = Depends(require_permission(Permission.PAUSE_TOURNAMENT))
):
    """Pause an active tournament."""
    try:
        with with_transaction(db):
            tournament = db.query(TournamentModel).filter(TournamentModel.id == tournament_id).first()
            
            if not tournament:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Tournament not found"
                )
            
            if tournament.status != TournamentStatus.ACTIVE.value:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Only active tournaments can be paused"
                )
            
            tournament.status = TournamentStatus.PAUSED.value
            tournament.updated_at = datetime.utcnow()
            
            # Send notifications to all participants
            background_tasks.add_task(
                notify_tournament_participants,
                tournament_id,
                "tournament_paused",
                {"tournament_name": tournament.name, "message": "Tournament has been paused"}
            )
            
            # Send audit log
            background_tasks.add_task(
                send_audit_log,
                "tournament_pause",
                current_user.user_id,
                current_user.email,
                "tournament",
                tournament_id,
                {"tournament_name": tournament.name}
            )
            
            return ApiResponse(
                success=True,
                data={"message": "Tournament paused successfully", "tournament_id": tournament_id}
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to pause tournament {tournament_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to pause tournament"
        )


@app.post("/api/v1/tournaments/{tournament_id}/resume")
async def resume_tournament(
    tournament_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: AuthUser = Depends(require_permission(Permission.PAUSE_TOURNAMENT))
):
    """Resume a paused tournament."""
    try:
        with with_transaction(db):
            tournament = db.query(TournamentModel).filter(TournamentModel.id == tournament_id).first()
            
            if not tournament:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Tournament not found"
                )
            
            if tournament.status != TournamentStatus.PAUSED.value:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Only paused tournaments can be resumed"
                )
            
            tournament.status = TournamentStatus.ACTIVE.value
            tournament.updated_at = datetime.utcnow()
            
            # Send notifications to all participants
            background_tasks.add_task(
                notify_tournament_participants,
                tournament_id,
                "tournament_resumed",
                {"tournament_name": tournament.name, "message": "Tournament has been resumed"}
            )
            
            # Send audit log
            background_tasks.add_task(
                send_audit_log,
                "tournament_resume",
                current_user.user_id,
                current_user.email,
                "tournament",
                tournament_id,
                {"tournament_name": tournament.name}
            )
            
            return ApiResponse(
                success=True,
                data={"message": "Tournament resumed successfully", "tournament_id": tournament_id}
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to resume tournament {tournament_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to resume tournament"
        )


@app.delete("/api/v1/tournaments/{tournament_id}")
async def delete_tournament(
    tournament_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: AuthUser = Depends(require_permission(Permission.DELETE_TOURNAMENT))
):
    """Delete a tournament (soft delete)."""
    try:
        with with_transaction(db):
            tournament = db.query(TournamentModel).filter(TournamentModel.id == tournament_id).first()
            
            if not tournament:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Tournament not found"
                )
            
            # Check if tournament can be deleted
            if tournament.status == TournamentStatus.ACTIVE.value:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Cannot delete an active tournament. Pause it first."
                )
            
            # Soft delete by changing status
            tournament.status = TournamentStatus.CANCELLED.value
            tournament.updated_at = datetime.utcnow()
            
            # Send audit log
            background_tasks.add_task(
                send_audit_log,
                "tournament_delete",
                current_user.user_id,
                current_user.email,
                "tournament",
                tournament_id,
                {"tournament_name": tournament.name}
            )
            
            return ApiResponse(
                success=True,
                data={"message": "Tournament cancelled successfully"}
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete tournament {tournament_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete tournament"
        )


# Background task functions
async def deploy_tournament_infrastructure(tournament_id: str, tournament_data: Dict[str, Any], user_id: str):
    """Deploy tournament infrastructure in background."""
    try:
        # Initialize ELO ratings for tournament
        if tournament_data.get('config', {}).get('elo_enabled', True):
            await initialize_elo_system(tournament_id, tournament_data)
        
        # Set up leaderboard
        await initialize_leaderboard(tournament_id)
        
        # Mark tournament as active
        # In real implementation, this would be done after all infrastructure is ready
        await asyncio.sleep(5)  # Simulate deployment time
        
        # Update tournament status to active
        # This would be done through a database call in real implementation
        logger.info(f"Tournament {tournament_id} deployed successfully")
        
    except Exception as e:
        logger.error(f"Failed to deploy tournament {tournament_id}: {e}")
        # In real implementation, mark tournament as failed


async def initialize_elo_system(tournament_id: str, tournament_data: Dict[str, Any]):
    """Initialize ELO rating system for tournament."""
    try:
        response = await http_client.post(
            f"{ELO_SERVICE_URL}/api/v1/elo/tournaments/{tournament_id}/initialize",
            json={
                "k_factor": tournament_data.get('config', {}).get('k_factor', 32),
                "initial_elo": tournament_data.get('config', {}).get('initial_elo', 1500)
            }
        )
        response.raise_for_status()
        logger.info(f"ELO system initialized for tournament {tournament_id}")
    except Exception as e:
        logger.error(f"Failed to initialize ELO system for tournament {tournament_id}: {e}")
        raise


async def initialize_leaderboard(tournament_id: str):
    """Initialize leaderboard for tournament."""
    try:
        response = await http_client.post(
            f"{LEADERBOARD_SERVICE_URL}/api/v1/leaderboards",
            json={"tournament_id": tournament_id}
        )
        response.raise_for_status()
        logger.info(f"Leaderboard initialized for tournament {tournament_id}")
    except Exception as e:
        logger.error(f"Failed to initialize leaderboard for tournament {tournament_id}: {e}")
        raise


async def notify_tournament_participants(tournament_id: str, notification_type: str, data: Dict[str, Any]):
    """Send notifications to tournament participants."""
    try:
        response = await http_client.post(
            f"{NOTIFICATION_SERVICE_URL}/api/v1/notifications/tournament/{tournament_id}",
            json={
                "type": notification_type,
                "data": data
            }
        )
        response.raise_for_status()
        logger.info(f"Notifications sent for tournament {tournament_id}")
    except Exception as e:
        logger.error(f"Failed to send notifications for tournament {tournament_id}: {e}")


async def send_audit_log(event_type: str, user_id: str, user_email: str, resource_type: str, resource_id: str, data: Dict[str, Any]):
    """Send audit log entry."""
    try:
        response = await http_client.post(
            f"{AUDIT_SERVICE_URL}/api/v1/audit",
            json={
                "event_type": event_type,
                "user_id": user_id,
                "user_email": user_email,
                "resource_type": resource_type,
                "resource_id": resource_id,
                "action": event_type,
                "new_values": data
            }
        )
        response.raise_for_status()
    except Exception as e:
        logger.error(f"Failed to send audit log: {e}")


# Startup and shutdown events
@app.on_event("startup")
async def startup_event():
    """Application startup."""
    logger.info(f"Tournament API starting up (version: {VERSION}, environment: {ENVIRONMENT})")


@app.on_event("shutdown")
async def shutdown_event():
    """Application shutdown."""
    logger.info("Tournament API shutting down")
    await http_client.aclose()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        reload=DEBUG,
        log_level="info"
    ) 