-- Tournament Management System Database Initialization
-- This script sets up the initial database schema and extensions

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create custom data types
CREATE TYPE tournament_status AS ENUM ('deploying', 'active', 'paused', 'ended', 'cancelled');
CREATE TYPE tournament_type AS ENUM ('single_elimination', 'double_elimination', 'round_robin', 'swiss');
CREATE TYPE match_status AS ENUM ('scheduled', 'in_progress', 'completed', 'cancelled', 'postponed');
CREATE TYPE result_status AS ENUM ('pending', 'pending_review', 'approved', 'rejected', 'disputed');
CREATE TYPE team_status AS ENUM ('pending', 'approved', 'rejected', 'withdrawn', 'suspended');
CREATE TYPE notification_type AS ENUM ('email', 'sms', 'push', 'in_app');
CREATE TYPE notification_status AS ENUM ('pending', 'sent', 'delivered', 'failed', 'bounced');
CREATE TYPE audit_event_type AS ENUM (
    'tournament_create', 'tournament_update', 'tournament_deploy', 'tournament_pause', 'tournament_resume',
    'team_register', 'team_approve', 'team_reject', 'team_withdraw',
    'match_schedule', 'match_reschedule', 'match_cancel', 'result_submit', 'result_approve', 'result_reject',
    'elo_update', 'leaderboard_update', 'hash_generate', 'hash_verify', 'hash_tampered',
    'user_login', 'user_logout', 'user_create', 'user_update', 'user_delete',
    'config_update', 'system_start', 'system_stop', 'error_occurred'
);

-- Core tables
CREATE TABLE tournaments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    tournament_type tournament_type NOT NULL DEFAULT 'single_elimination',
    status tournament_status NOT NULL DEFAULT 'deploying',
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    max_teams INTEGER NOT NULL DEFAULT 32,
    current_teams INTEGER NOT NULL DEFAULT 0,
    
    -- Configuration settings
    config JSONB NOT NULL DEFAULT '{}',
    elo_enabled BOOLEAN NOT NULL DEFAULT true,
    hash_verification BOOLEAN NOT NULL DEFAULT true,
    human_review BOOLEAN NOT NULL DEFAULT true,
    k_factor INTEGER NOT NULL DEFAULT 32,
    initial_elo INTEGER NOT NULL DEFAULT 1500,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID,
    
    -- Hash for integrity
    hash VARCHAR(64) NOT NULL,
    
    CONSTRAINT check_dates CHECK (end_date > start_date),
    CONSTRAINT check_max_teams CHECK (max_teams > 0),
    CONSTRAINT check_current_teams CHECK (current_teams >= 0 AND current_teams <= max_teams),
    CONSTRAINT check_k_factor CHECK (k_factor > 0 AND k_factor <= 100),
    CONSTRAINT check_initial_elo CHECK (initial_elo >= 100 AND initial_elo <= 3000)
);

CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    short_name VARCHAR(50),
    description TEXT,
    captain_name VARCHAR(255) NOT NULL,
    captain_email VARCHAR(255) NOT NULL,
    max_players INTEGER NOT NULL DEFAULT 8,
    current_players INTEGER NOT NULL DEFAULT 1,
    status team_status NOT NULL DEFAULT 'pending',
    
    -- Contact information (encrypted)
    contact_info JSONB,
    
    -- Team metadata
    logo_url VARCHAR(500),
    website_url VARCHAR(500),
    social_links JSONB DEFAULT '{}',
    
    -- Registration info
    registered_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by UUID,
    
    -- Hash for integrity
    hash VARCHAR(64) NOT NULL,
    
    CONSTRAINT check_max_players CHECK (max_players > 0),
    CONSTRAINT check_current_players CHECK (current_players >= 0 AND current_players <= max_players),
    CONSTRAINT check_email_format CHECK (captain_email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

CREATE TABLE tournament_teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    seed INTEGER,
    
    UNIQUE(tournament_id, team_id),
    UNIQUE(tournament_id, seed)
);

CREATE TABLE players (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'player',
    
    -- Player info (encrypted)
    contact_info JSONB,
    
    -- Status
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Hash for integrity
    hash VARCHAR(64) NOT NULL,
    
    CONSTRAINT check_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    team1_id UUID NOT NULL REFERENCES teams(id),
    team2_id UUID NOT NULL REFERENCES teams(id),
    
    -- Match details
    round INTEGER NOT NULL DEFAULT 1,
    match_number INTEGER NOT NULL,
    scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL,
    duration INTERVAL DEFAULT '2 hours',
    venue VARCHAR(255),
    
    -- Status and results
    status match_status NOT NULL DEFAULT 'scheduled',
    winner_id UUID REFERENCES teams(id),
    score VARCHAR(50),
    game_scores JSONB DEFAULT '[]',
    
    -- Officials
    referee_id UUID,
    referee_name VARCHAR(255),
    
    -- Timestamps
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Hash for integrity
    hash VARCHAR(64) NOT NULL,
    
    CONSTRAINT check_different_teams CHECK (team1_id != team2_id),
    CONSTRAINT check_winner_is_participant CHECK (winner_id IS NULL OR winner_id IN (team1_id, team2_id)),
    CONSTRAINT check_completion CHECK (
        (status = 'completed' AND winner_id IS NOT NULL AND completed_at IS NOT NULL) OR
        (status != 'completed' AND (winner_id IS NULL OR completed_at IS NULL))
    )
);

CREATE TABLE match_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    
    -- Result data
    winner_id UUID NOT NULL REFERENCES teams(id),
    loser_id UUID NOT NULL REFERENCES teams(id),
    score VARCHAR(50) NOT NULL,
    game_scores JSONB DEFAULT '[]',
    duration INTERVAL,
    
    -- Submission info
    submitted_by VARCHAR(255) NOT NULL,
    submitted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Review workflow
    status result_status NOT NULL DEFAULT 'pending',
    reviewed_by UUID,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    review_notes TEXT,
    
    -- Evidence
    evidence_files JSONB DEFAULT '[]',
    video_evidence_url VARCHAR(500),
    
    -- Hash for integrity and tampering detection
    original_hash VARCHAR(64) NOT NULL,
    current_hash VARCHAR(64) NOT NULL,
    hash_verified BOOLEAN NOT NULL DEFAULT true,
    
    CONSTRAINT check_different_teams CHECK (winner_id != loser_id),
    CONSTRAINT check_hash_integrity CHECK (hash_verified = (original_hash = current_hash))
);

CREATE TABLE elo_ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    
    -- ELO data
    current_elo INTEGER NOT NULL DEFAULT 1500,
    previous_elo INTEGER NOT NULL DEFAULT 1500,
    change INTEGER NOT NULL DEFAULT 0,
    
    -- Match context
    match_id UUID REFERENCES matches(id),
    opponent_id UUID REFERENCES teams(id),
    k_factor INTEGER NOT NULL DEFAULT 32,
    expected_score DECIMAL(5,4) NOT NULL,
    actual_score DECIMAL(3,2) NOT NULL,
    
    -- Calculation metadata
    calculation_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    calculation_id UUID NOT NULL DEFAULT uuid_generate_v4(),
    
    -- Hash for integrity
    hash VARCHAR(64) NOT NULL,
    
    UNIQUE(tournament_id, team_id, match_id),
    CONSTRAINT check_elo_range CHECK (current_elo >= 100 AND current_elo <= 3000),
    CONSTRAINT check_k_factor CHECK (k_factor > 0 AND k_factor <= 100),
    CONSTRAINT check_expected_score CHECK (expected_score >= 0 AND expected_score <= 1),
    CONSTRAINT check_actual_score CHECK (actual_score IN (0, 0.5, 1))
);

CREATE TABLE leaderboards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    
    -- Standings data
    standings JSONB NOT NULL,
    total_teams INTEGER NOT NULL DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Generation metadata
    generated_by VARCHAR(255) NOT NULL DEFAULT 'system',
    generation_time_ms INTEGER NOT NULL DEFAULT 0,
    
    -- Hash for integrity
    hash VARCHAR(64) NOT NULL,
    
    CONSTRAINT check_total_teams CHECK (total_teams >= 0)
);

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Recipients
    recipient_type VARCHAR(50) NOT NULL, -- 'team', 'user', 'admin', 'all'
    recipient_id UUID,
    recipient_email VARCHAR(255),
    
    -- Content
    type notification_type NOT NULL,
    subject VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    template_name VARCHAR(100),
    template_data JSONB DEFAULT '{}',
    
    -- Delivery
    status notification_status NOT NULL DEFAULT 'pending',
    delivery_attempts INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 3,
    
    -- Scheduling
    scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    sent_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    
    -- Error handling
    error_message TEXT,
    retry_after TIMESTAMP WITH TIME ZONE,
    
    -- Context
    tournament_id UUID REFERENCES tournaments(id),
    match_id UUID REFERENCES matches(id),
    team_id UUID REFERENCES teams(id),
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Event details
    event_type audit_event_type NOT NULL,
    event_id UUID NOT NULL DEFAULT uuid_generate_v4(),
    
    -- User and session info
    user_id UUID,
    user_email VARCHAR(255),
    session_id VARCHAR(255),
    ip_address INET,
    user_agent TEXT,
    
    -- Action details
    resource_type VARCHAR(100),
    resource_id UUID,
    action VARCHAR(255) NOT NULL,
    
    -- Data changes
    old_values JSONB,
    new_values JSONB,
    changes JSONB,
    
    -- Context
    tournament_id UUID REFERENCES tournaments(id),
    team_id UUID REFERENCES teams(id),
    match_id UUID REFERENCES matches(id),
    
    -- Metadata
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    correlation_id UUID,
    
    -- Security
    hash VARCHAR(64) NOT NULL,
    signature VARCHAR(255)
);

-- Create indexes for performance
CREATE INDEX idx_tournaments_status ON tournaments(status);
CREATE INDEX idx_tournaments_dates ON tournaments(start_date, end_date);
CREATE INDEX idx_tournaments_created_at ON tournaments(created_at);

CREATE INDEX idx_teams_status ON teams(status);
CREATE INDEX idx_teams_captain_email ON teams(captain_email);
CREATE INDEX idx_teams_registered_at ON teams(registered_at);

CREATE INDEX idx_tournament_teams_tournament ON tournament_teams(tournament_id);
CREATE INDEX idx_tournament_teams_team ON tournament_teams(team_id);
CREATE INDEX idx_tournament_teams_seed ON tournament_teams(tournament_id, seed);

CREATE INDEX idx_players_team ON players(team_id);
CREATE INDEX idx_players_email ON players(email);

CREATE INDEX idx_matches_tournament ON matches(tournament_id);
CREATE INDEX idx_matches_teams ON matches(team1_id, team2_id);
CREATE INDEX idx_matches_scheduled_at ON matches(scheduled_at);
CREATE INDEX idx_matches_status ON matches(status);

CREATE INDEX idx_match_results_match ON match_results(match_id);
CREATE INDEX idx_match_results_status ON match_results(status);
CREATE INDEX idx_match_results_submitted_at ON match_results(submitted_at);

CREATE INDEX idx_elo_ratings_tournament_team ON elo_ratings(tournament_id, team_id);
CREATE INDEX idx_elo_ratings_match ON elo_ratings(match_id);
CREATE INDEX idx_elo_ratings_timestamp ON elo_ratings(calculation_timestamp);

CREATE INDEX idx_leaderboards_tournament ON leaderboards(tournament_id);
CREATE INDEX idx_leaderboards_updated ON leaderboards(last_updated);

CREATE INDEX idx_notifications_recipient ON notifications(recipient_type, recipient_id);
CREATE INDEX idx_notifications_status ON notifications(status);
CREATE INDEX idx_notifications_scheduled ON notifications(scheduled_at);
CREATE INDEX idx_notifications_tournament ON notifications(tournament_id);

CREATE INDEX idx_audit_logs_event_type ON audit_logs(event_type);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_tournament ON audit_logs(tournament_id);

-- Create functions for automatic hash generation
CREATE OR REPLACE FUNCTION generate_record_hash(record_data JSONB) 
RETURNS VARCHAR(64) AS $$
BEGIN
    RETURN encode(digest(record_data::text, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create trigger functions for automatic timestamp updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for automatic timestamp updates
CREATE TRIGGER update_tournaments_updated_at 
    BEFORE UPDATE ON tournaments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_matches_updated_at 
    BEFORE UPDATE ON matches 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_notifications_updated_at 
    BEFORE UPDATE ON notifications 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert initial system data
INSERT INTO tournaments (
    id, name, description, tournament_type, status, 
    start_date, end_date, max_teams, hash
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    'System Default Tournament',
    'Default tournament for system initialization',
    'single_elimination',
    'ended',
    '2024-01-01 00:00:00+00',
    '2024-01-02 00:00:00+00',
    2,
    generate_record_hash('{"name":"System Default Tournament"}'::jsonb)
);

-- Create views for common queries
CREATE VIEW tournament_standings AS
SELECT 
    t.id as tournament_id,
    t.name as tournament_name,
    tt.team_id,
    teams.name as team_name,
    COALESCE(stats.matches_played, 0) as matches_played,
    COALESCE(stats.wins, 0) as wins,
    COALESCE(stats.losses, 0) as losses,
    ROUND(COALESCE(stats.wins::decimal / NULLIF(stats.matches_played, 0), 0) * 100, 2) as win_percentage,
    COALESCE(elo.current_elo, t.initial_elo) as current_elo,
    COALESCE(stats.points, 0) as points
FROM tournaments t
JOIN tournament_teams tt ON t.id = tt.tournament_id
JOIN teams ON tt.team_id = teams.id
LEFT JOIN (
    SELECT 
        tournament_id,
        team_id,
        MAX(current_elo) as current_elo
    FROM elo_ratings
    GROUP BY tournament_id, team_id
) elo ON t.id = elo.tournament_id AND tt.team_id = elo.team_id
LEFT JOIN (
    SELECT 
        m.tournament_id,
        team_stats.team_id,
        SUM(team_stats.matches) as matches_played,
        SUM(team_stats.wins) as wins,
        SUM(team_stats.losses) as losses,
        SUM(team_stats.wins * 3) as points
    FROM matches m
    CROSS JOIN LATERAL (
        VALUES 
            (m.team1_id, 1, CASE WHEN m.winner_id = m.team1_id THEN 1 ELSE 0 END, CASE WHEN m.winner_id = m.team2_id THEN 1 ELSE 0 END),
            (m.team2_id, 1, CASE WHEN m.winner_id = m.team2_id THEN 1 ELSE 0 END, CASE WHEN m.winner_id = m.team1_id THEN 1 ELSE 0 END)
    ) AS team_stats(team_id, matches, wins, losses)
    WHERE m.status = 'completed'
    GROUP BY m.tournament_id, team_stats.team_id
) stats ON t.id = stats.tournament_id AND tt.team_id = stats.team_id
ORDER BY t.id, COALESCE(stats.points, 0) DESC, COALESCE(elo.current_elo, t.initial_elo) DESC;

COMMENT ON DATABASE tournament_db IS 'Tournament Management System Database';
COMMENT ON TABLE tournaments IS 'Core tournament information and configuration';
COMMENT ON TABLE teams IS 'Team registration and management data';
COMMENT ON TABLE matches IS 'Match scheduling and results';
COMMENT ON TABLE elo_ratings IS 'ELO rating calculations and history';
COMMENT ON TABLE audit_logs IS 'Comprehensive audit trail for all system activities'; 