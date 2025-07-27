"""
Shared Pydantic models for tournament microservices.
Provides common data structures and validation schemas.
"""
from typing import Optional, List, Dict, Any, Union
from datetime import datetime, date
from enum import Enum
from decimal import Decimal
from pydantic import BaseModel, Field, EmailStr, UUID4, validator
import uuid


# Enums for type safety
class TournamentStatus(str, Enum):
    DEPLOYING = "deploying"
    ACTIVE = "active"
    PAUSED = "paused"
    ENDED = "ended"
    CANCELLED = "cancelled"


class TournamentType(str, Enum):
    SINGLE_ELIMINATION = "single_elimination"
    DOUBLE_ELIMINATION = "double_elimination"
    ROUND_ROBIN = "round_robin"
    SWISS = "swiss"


class MatchStatus(str, Enum):
    SCHEDULED = "scheduled"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    POSTPONED = "postponed"


class ResultStatus(str, Enum):
    PENDING = "pending"
    PENDING_REVIEW = "pending_review"
    APPROVED = "approved"
    REJECTED = "rejected"
    DISPUTED = "disputed"


class TeamStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    WITHDRAWN = "withdrawn"
    SUSPENDED = "suspended"


class NotificationType(str, Enum):
    EMAIL = "email"
    SMS = "sms"
    PUSH = "push"
    IN_APP = "in_app"


class NotificationStatus(str, Enum):
    PENDING = "pending"
    SENT = "sent"
    DELIVERED = "delivered"
    FAILED = "failed"
    BOUNCED = "bounced"


class AuditEventType(str, Enum):
    TOURNAMENT_CREATE = "tournament_create"
    TOURNAMENT_UPDATE = "tournament_update"
    TOURNAMENT_DEPLOY = "tournament_deploy"
    TOURNAMENT_PAUSE = "tournament_pause"
    TOURNAMENT_RESUME = "tournament_resume"
    TEAM_REGISTER = "team_register"
    TEAM_APPROVE = "team_approve"
    TEAM_REJECT = "team_reject"
    TEAM_WITHDRAW = "team_withdraw"
    MATCH_SCHEDULE = "match_schedule"
    MATCH_RESCHEDULE = "match_reschedule"
    MATCH_CANCEL = "match_cancel"
    RESULT_SUBMIT = "result_submit"
    RESULT_APPROVE = "result_approve"
    RESULT_REJECT = "result_reject"
    ELO_UPDATE = "elo_update"
    LEADERBOARD_UPDATE = "leaderboard_update"
    HASH_GENERATE = "hash_generate"
    HASH_VERIFY = "hash_verify"
    HASH_TAMPERED = "hash_tampered"
    USER_LOGIN = "user_login"
    USER_LOGOUT = "user_logout"
    USER_CREATE = "user_create"
    USER_UPDATE = "user_update"
    USER_DELETE = "user_delete"
    CONFIG_UPDATE = "config_update"
    SYSTEM_START = "system_start"
    SYSTEM_STOP = "system_stop"
    ERROR_OCCURRED = "error_occurred"


# Base models
class BaseModelWithTimestamp(BaseModel):
    """Base model with timestamp fields."""
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    
    class Config:
        orm_mode = True
        validate_assignment = True
        use_enum_values = True


class BaseModelWithHash(BaseModelWithTimestamp):
    """Base model with hash field for integrity verification."""
    hash: Optional[str] = None


# Tournament models
class TournamentConfig(BaseModel):
    """Tournament configuration settings."""
    elo_enabled: bool = True
    hash_verification: bool = True
    human_review: bool = True
    k_factor: int = Field(default=32, ge=1, le=100)
    initial_elo: int = Field(default=1500, ge=100, le=3000)
    auto_scheduling: bool = True
    max_players_per_team: int = Field(default=8, ge=1, le=20)
    match_duration: int = Field(default=120, ge=30, le=480)  # minutes
    
    class Config:
        schema_extra = {
            "example": {
                "elo_enabled": True,
                "hash_verification": True,
                "human_review": True,
                "k_factor": 32,
                "initial_elo": 1500,
                "auto_scheduling": True,
                "max_players_per_team": 8,
                "match_duration": 120
            }
        }


class TournamentBase(BaseModel):
    """Base tournament model."""
    name: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    tournament_type: TournamentType = TournamentType.SINGLE_ELIMINATION
    start_date: datetime
    end_date: datetime
    max_teams: int = Field(default=32, ge=2, le=256)
    config: TournamentConfig = TournamentConfig()
    
    @validator('end_date')
    def end_date_must_be_after_start_date(cls, v, values):
        if 'start_date' in values and v <= values['start_date']:
            raise ValueError('end_date must be after start_date')
        return v


class TournamentCreate(TournamentBase):
    """Tournament creation model."""
    pass


class TournamentUpdate(BaseModel):
    """Tournament update model."""
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    status: Optional[TournamentStatus] = None
    end_date: Optional[datetime] = None
    config: Optional[TournamentConfig] = None


class Tournament(TournamentBase, BaseModelWithHash):
    """Tournament response model."""
    id: UUID4
    status: TournamentStatus = TournamentStatus.DEPLOYING
    current_teams: int = 0
    created_by: Optional[UUID4] = None


# Team models
class ContactInfo(BaseModel):
    """Contact information model (will be encrypted)."""
    phone: Optional[str] = None
    address: Optional[str] = None
    emergency_contact: Optional[str] = None


class TeamBase(BaseModel):
    """Base team model."""
    name: str = Field(..., min_length=1, max_length=255)
    short_name: Optional[str] = Field(None, max_length=50)
    description: Optional[str] = None
    captain_name: str = Field(..., min_length=1, max_length=255)
    captain_email: EmailStr
    max_players: int = Field(default=8, ge=1, le=20)
    contact_info: Optional[ContactInfo] = None
    logo_url: Optional[str] = None
    website_url: Optional[str] = None
    social_links: Optional[Dict[str, str]] = {}


class TeamCreate(TeamBase):
    """Team creation model."""
    pass


class TeamUpdate(BaseModel):
    """Team update model."""
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    captain_name: Optional[str] = Field(None, min_length=1, max_length=255)
    captain_email: Optional[EmailStr] = None
    max_players: Optional[int] = Field(None, ge=1, le=20)
    contact_info: Optional[ContactInfo] = None
    logo_url: Optional[str] = None
    website_url: Optional[str] = None
    social_links: Optional[Dict[str, str]] = None


class Team(TeamBase, BaseModelWithHash):
    """Team response model."""
    id: UUID4
    status: TeamStatus = TeamStatus.PENDING
    current_players: int = 1
    registered_at: datetime
    approved_at: Optional[datetime] = None
    approved_by: Optional[UUID4] = None


# Player models
class PlayerBase(BaseModel):
    """Base player model."""
    name: str = Field(..., min_length=1, max_length=255)
    email: EmailStr
    role: str = Field(default="player", max_length=50)
    contact_info: Optional[ContactInfo] = None


class PlayerCreate(PlayerBase):
    """Player creation model."""
    team_id: UUID4


class Player(PlayerBase, BaseModelWithHash):
    """Player response model."""
    id: UUID4
    team_id: UUID4
    status: str = "active"
    joined_at: datetime


# Match models
class MatchBase(BaseModel):
    """Base match model."""
    tournament_id: UUID4
    team1_id: UUID4
    team2_id: UUID4
    round: int = Field(default=1, ge=1)
    match_number: int = Field(ge=1)
    scheduled_at: datetime
    duration: Optional[int] = Field(default=120, ge=30, le=480)  # minutes
    venue: Optional[str] = None
    referee_name: Optional[str] = None


class MatchCreate(MatchBase):
    """Match creation model."""
    pass


class MatchUpdate(BaseModel):
    """Match update model."""
    scheduled_at: Optional[datetime] = None
    duration: Optional[int] = Field(None, ge=30, le=480)
    venue: Optional[str] = None
    referee_name: Optional[str] = None
    status: Optional[MatchStatus] = None


class Match(MatchBase, BaseModelWithHash):
    """Match response model."""
    id: UUID4
    status: MatchStatus = MatchStatus.SCHEDULED
    winner_id: Optional[UUID4] = None
    score: Optional[str] = None
    game_scores: Optional[List[str]] = []
    referee_id: Optional[UUID4] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None


# Match Result models
class MatchResultBase(BaseModel):
    """Base match result model."""
    match_id: UUID4
    winner_id: UUID4
    loser_id: UUID4
    score: str = Field(..., min_length=1)
    game_scores: Optional[List[str]] = []
    duration: Optional[int] = None  # minutes
    submitted_by: str = Field(..., min_length=1)
    evidence_files: Optional[List[str]] = []
    video_evidence_url: Optional[str] = None


class MatchResultCreate(MatchResultBase):
    """Match result creation model."""
    pass


class MatchResultUpdate(BaseModel):
    """Match result update model for review workflow."""
    status: ResultStatus
    review_notes: Optional[str] = None


class MatchResult(MatchResultBase, BaseModelWithTimestamp):
    """Match result response model."""
    id: UUID4
    status: ResultStatus = ResultStatus.PENDING
    submitted_at: datetime
    reviewed_by: Optional[UUID4] = None
    reviewed_at: Optional[datetime] = None
    review_notes: Optional[str] = None
    original_hash: str
    current_hash: str
    hash_verified: bool = True


# ELO Rating models
class EloRatingBase(BaseModel):
    """Base ELO rating model."""
    tournament_id: UUID4
    team_id: UUID4
    current_elo: int = Field(..., ge=100, le=3000)
    previous_elo: int = Field(..., ge=100, le=3000)
    change: int
    k_factor: int = Field(..., ge=1, le=100)
    expected_score: Decimal = Field(..., ge=0, le=1)
    actual_score: Decimal = Field(..., ge=0, le=1)


class EloRatingCreate(EloRatingBase):
    """ELO rating creation model."""
    match_id: UUID4
    opponent_id: UUID4


class EloRating(EloRatingBase, BaseModelWithHash):
    """ELO rating response model."""
    id: UUID4
    match_id: Optional[UUID4] = None
    opponent_id: Optional[UUID4] = None
    calculation_timestamp: datetime
    calculation_id: UUID4


# Leaderboard models
class TeamStanding(BaseModel):
    """Team standing in leaderboard."""
    rank: int = Field(..., ge=1)
    team_id: UUID4
    team_name: str
    matches_played: int = Field(default=0, ge=0)
    wins: int = Field(default=0, ge=0)
    losses: int = Field(default=0, ge=0)
    win_percentage: float = Field(default=0.0, ge=0.0, le=100.0)
    current_elo: int = Field(..., ge=100, le=3000)
    points: int = Field(default=0, ge=0)


class LeaderboardBase(BaseModel):
    """Base leaderboard model."""
    tournament_id: UUID4
    standings: List[TeamStanding]
    total_teams: int = Field(..., ge=0)


class Leaderboard(LeaderboardBase, BaseModelWithHash):
    """Leaderboard response model."""
    id: UUID4
    last_updated: datetime
    generated_by: str = "system"
    generation_time_ms: int = Field(default=0, ge=0)


# Notification models
class NotificationBase(BaseModel):
    """Base notification model."""
    recipient_type: str = Field(..., max_length=50)
    recipient_id: Optional[UUID4] = None
    recipient_email: Optional[EmailStr] = None
    type: NotificationType
    subject: str = Field(..., min_length=1, max_length=255)
    content: str = Field(..., min_length=1)
    template_name: Optional[str] = Field(None, max_length=100)
    template_data: Optional[Dict[str, Any]] = {}
    scheduled_at: Optional[datetime] = None
    tournament_id: Optional[UUID4] = None
    match_id: Optional[UUID4] = None
    team_id: Optional[UUID4] = None


class NotificationCreate(NotificationBase):
    """Notification creation model."""
    pass


class Notification(NotificationBase, BaseModelWithTimestamp):
    """Notification response model."""
    id: UUID4
    status: NotificationStatus = NotificationStatus.PENDING
    delivery_attempts: int = 0
    max_attempts: int = 3
    sent_at: Optional[datetime] = None
    delivered_at: Optional[datetime] = None
    error_message: Optional[str] = None
    retry_after: Optional[datetime] = None


# Audit log models
class AuditLogBase(BaseModel):
    """Base audit log model."""
    event_type: AuditEventType
    user_id: Optional[UUID4] = None
    user_email: Optional[EmailStr] = None
    session_id: Optional[str] = None
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    resource_type: Optional[str] = Field(None, max_length=100)
    resource_id: Optional[UUID4] = None
    action: str = Field(..., max_length=255)
    old_values: Optional[Dict[str, Any]] = {}
    new_values: Optional[Dict[str, Any]] = {}
    changes: Optional[Dict[str, Any]] = {}
    tournament_id: Optional[UUID4] = None
    team_id: Optional[UUID4] = None
    match_id: Optional[UUID4] = None
    correlation_id: Optional[UUID4] = None


class AuditLogCreate(AuditLogBase):
    """Audit log creation model."""
    pass


class AuditLog(AuditLogBase):
    """Audit log response model."""
    id: UUID4
    event_id: UUID4
    timestamp: datetime
    hash: str
    signature: Optional[str] = None


# API Response models
class ApiResponse(BaseModel):
    """Standard API response wrapper."""
    success: bool
    data: Optional[Any] = None
    error: Optional[Dict[str, Any]] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    request_id: UUID4 = Field(default_factory=uuid.uuid4)


class ErrorDetail(BaseModel):
    """Error detail model."""
    code: str
    message: str
    details: Optional[Dict[str, Any]] = None


class PaginationParams(BaseModel):
    """Pagination parameters."""
    page: int = Field(default=1, ge=1)
    size: int = Field(default=20, ge=1, le=100)
    sort_by: Optional[str] = None
    sort_order: Optional[str] = Field(default="asc", regex="^(asc|desc)$")


class PaginatedResponse(BaseModel):
    """Paginated response model."""
    items: List[Any]
    total: int
    page: int
    size: int
    pages: int


# Health check models
class HealthCheck(BaseModel):
    """Health check response model."""
    status: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    version: str = "1.0.0"
    environment: str = "development"
    services: Dict[str, bool] = {}


# Export all models
__all__ = [
    # Enums
    "TournamentStatus", "TournamentType", "MatchStatus", "ResultStatus",
    "TeamStatus", "NotificationType", "NotificationStatus", "AuditEventType",
    
    # Base models
    "BaseModelWithTimestamp", "BaseModelWithHash",
    
    # Tournament models
    "TournamentConfig", "TournamentBase", "TournamentCreate", "TournamentUpdate", "Tournament",
    
    # Team models
    "ContactInfo", "TeamBase", "TeamCreate", "TeamUpdate", "Team",
    
    # Player models
    "PlayerBase", "PlayerCreate", "Player",
    
    # Match models
    "MatchBase", "MatchCreate", "MatchUpdate", "Match",
    
    # Match result models
    "MatchResultBase", "MatchResultCreate", "MatchResultUpdate", "MatchResult",
    
    # ELO rating models
    "EloRatingBase", "EloRatingCreate", "EloRating",
    
    # Leaderboard models
    "TeamStanding", "LeaderboardBase", "Leaderboard",
    
    # Notification models
    "NotificationBase", "NotificationCreate", "Notification",
    
    # Audit log models
    "AuditLogBase", "AuditLogCreate", "AuditLog",
    
    # API models
    "ApiResponse", "ErrorDetail", "PaginationParams", "PaginatedResponse", "HealthCheck"
] 