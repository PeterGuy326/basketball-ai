-- 篮球 AI 系统 TimescaleDB 数据库初始化脚本
-- 针对时序数据和球员轨迹优化

-- 启用 TimescaleDB 扩展
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- 1. 比赛基础信息表
CREATE TABLE IF NOT EXISTS games (
    game_id SERIAL PRIMARY KEY,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    team_a VARCHAR(100) NOT NULL,
    team_b VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 检测事件表（时序数据主表）
CREATE TABLE IF NOT EXISTS detection_events (
    timestamp TIMESTAMPTZ NOT NULL,
    game_id INTEGER REFERENCES games(game_id),
    event_type VARCHAR(50) NOT NULL,  -- 'person_detected', 'travel_suspect', 'foul_detected'
    player_id VARCHAR(50),
    confidence FLOAT,
    bbox_x1 FLOAT,
    bbox_y1 FLOAT,
    bbox_x2 FLOAT,
    bbox_y2 FLOAT,
    tracking_info JSONB,
    raw_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 转换为 TimescaleDB 超表（针对时序数据优化）
SELECT create_hypertable('detection_events', 'timestamp', if_not_exists => TRUE);

-- 3. 规则验证事件表
CREATE TABLE IF NOT EXISTS rule_events (
    timestamp TIMESTAMPTZ NOT NULL,
    game_id INTEGER REFERENCES games(game_id),
    rule_type VARCHAR(50) NOT NULL,  -- 'travel', 'double_dribble', 'foul'
    severity VARCHAR(20) DEFAULT 'info',  -- 'info', 'warning', 'violation'
    player_id VARCHAR(50),
    decision BOOLEAN,
    confidence FLOAT,
    context_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

SELECT create_hypertable('rule_events', 'timestamp', if_not_exists => TRUE);

-- 4. 球员统计聚合表
CREATE TABLE IF NOT EXISTS player_stats (
    timestamp TIMESTAMPTZ NOT NULL,
    game_id INTEGER REFERENCES games(game_id),
    player_id VARCHAR(50) NOT NULL,
    total_points INTEGER DEFAULT 0,
    rebounds INTEGER DEFAULT 0,
    steals INTEGER DEFAULT 0,
    fouls INTEGER DEFAULT 0,
    travel_violations INTEGER DEFAULT 0,
    playtime_seconds INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

SELECT create_hypertable('player_stats', 'timestamp', if_not_exists => TRUE);

-- 5. 系统性能监控表
CREATE TABLE IF NOT EXISTS system_metrics (
    timestamp TIMESTAMPTZ NOT NULL,
    service_name VARCHAR(100) NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    metric_value FLOAT,
    unit VARCHAR(20),
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

SELECT create_hypertable('system_metrics', 'timestamp', if_not_exists => TRUE);

-- 创建索引优化查询性能
CREATE INDEX IF NOT EXISTS idx_detection_events_game_type ON detection_events (game_id, event_type);
CREATE INDEX IF NOT EXISTS idx_rule_events_game_rule ON rule_events (game_id, rule_type);
CREATE INDEX IF NOT EXISTS idx_player_stats_game_player ON player_stats (game_id, player_id);
CREATE INDEX IF NOT EXISTS idx_system_metrics_service ON system_metrics (service_name, metric_name);

-- 创建数据保留策略（保留30天数据）
SELECT add_retention_policy('detection_events', INTERVAL '30 days', if_not_exists => TRUE);
SELECT add_retention_policy('rule_events', INTERVAL '30 days', if_not_exists => TRUE);
SELECT add_retention_policy('system_metrics', INTERVAL '7 days', if_not_exists => TRUE);

-- 插入测试数据
INSERT INTO games (start_time, team_a, team_b, status) VALUES 
    (NOW() - INTERVAL '1 hour', 'Lakers', 'Warriors', 'active'),
    (NOW() - INTERVAL '2 days', 'Bulls', 'Celtics', 'completed')
ON CONFLICT DO NOTHING;

-- 显示表创建结果
\echo '=== TimescaleDB 表结构初始化完成 ==='
\dt
\echo '=== 超表信息 ==='
SELECT hypertable_name, num_chunks FROM timescaledb_information.hypertables;