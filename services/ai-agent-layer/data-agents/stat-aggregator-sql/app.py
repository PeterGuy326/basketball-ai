from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from shared.common.config import load_config
from shared.common.logging import setup_logging
from sqlalchemy import create_engine, text
from datetime import datetime, timedelta
from typing import Optional
import json

app = FastAPI(title="StatAggregator-SQL")
cfg = load_config()
logger = setup_logging("stat-aggregator-sql")
engine = create_engine(cfg.db.url, future=True)


class StatResponse(BaseModel):
    total_points: int = 0
    rebounds: int = 0
    steals: int = 0
    fouls: int = 0
    travel_violations: int = 0
    playtime_seconds: int = 0


class GameSummary(BaseModel):
    game_id: int
    team_a: str
    team_b: str
    status: str
    detection_events_count: int
    rule_events_count: int
    start_time: datetime


class DetectionEventStats(BaseModel):
    event_type: str
    count: int
    avg_confidence: float


class RealtimeEvent(BaseModel):
    timestamp: datetime
    event_type: str
    event_id: str
    confidence: float
    player_id: Optional[str]
    details: dict


class RuleEventSummary(BaseModel):
    rule_type: str
    violation_count: int
    warning_count: int
    avg_confidence: float


@app.get("/health")
async def health_check():
    """健康检查接口"""
    try:
        with engine.connect() as conn:
            result = conn.execute(text("SELECT 1"))
            return {"status": "healthy", "database": "connected"}
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=503, detail="Database connection failed")


@app.get("/stats", response_model=StatResponse)
async def get_stats(
    game_id: Optional[int] = Query(None, description="指定比赛ID"),
    player_id: Optional[str] = Query(None, description="指定球员ID"),
    hours_back: int = Query(24, description="统计过去N小时的数据")
):
    """
    获取球员统计数据聚合
    - 如果指定 game_id 和 player_id，返回该球员在该比赛的统计
    - 如果只指定 player_id，返回该球员在指定时间范围内的统计
    - 如果都不指定，返回所有球员在指定时间范围内的汇总统计
    """
    try:
        # 基础 SQL 查询
        base_query = """
        SELECT 
            COALESCE(SUM(total_points), 0) as total_points,
            COALESCE(SUM(rebounds), 0) as rebounds, 
            COALESCE(SUM(steals), 0) as steals,
            COALESCE(SUM(fouls), 0) as fouls,
            COALESCE(SUM(travel_violations), 0) as travel_violations,
            COALESCE(SUM(playtime_seconds), 0) as playtime_seconds
        FROM player_stats 
        WHERE timestamp >= NOW() - make_interval(hours => :hours_back)
        """
        
        params = {"hours_back": hours_back}
        
        # 添加条件过滤
        if game_id:
            base_query += " AND game_id = :game_id"
            params["game_id"] = game_id
            
        if player_id:
            base_query += " AND player_id = :player_id"
            params["player_id"] = player_id

        with engine.connect() as conn:
            result = conn.execute(text(base_query), params)
            row = result.fetchone()
            
            if row:
                stats = StatResponse(
                    total_points=row[0],
                    rebounds=row[1], 
                    steals=row[2],
                    fouls=row[3],
                    travel_violations=row[4],
                    playtime_seconds=row[5]
                )
                logger.info(f"Retrieved stats for game_id={game_id}, player_id={player_id}: {stats}")
                return stats
            else:
                logger.info("No stats found, returning zeros")
                return StatResponse()
                
    except Exception as e:
        logger.error(f"Failed to retrieve stats: {e}")
        raise HTTPException(status_code=500, detail=f"Database query failed: {str(e)}")


@app.get("/games/summary", response_model=list[GameSummary])
async def get_games_summary(limit: int = Query(10, description="返回最近N场比赛")):
    """获取比赛汇总信息"""
    try:
        query = """
        SELECT 
            g.game_id,
            g.team_a,
            g.team_b, 
            g.status,
            g.start_time,
            COALESCE(de.detection_count, 0) as detection_events_count,
            COALESCE(re.rule_count, 0) as rule_events_count
        FROM games g
        LEFT JOIN (
            SELECT game_id, COUNT(*) as detection_count 
            FROM detection_events 
            WHERE timestamp >= NOW() - INTERVAL '7 days'
            GROUP BY game_id
        ) de ON g.game_id = de.game_id
        LEFT JOIN (
            SELECT game_id, COUNT(*) as rule_count 
            FROM rule_events 
            WHERE timestamp >= NOW() - INTERVAL '7 days'
            GROUP BY game_id  
        ) re ON g.game_id = re.game_id
        ORDER BY g.start_time DESC
        LIMIT :limit
        """
        
        with engine.connect() as conn:
            result = conn.execute(text(query), {"limit": limit})
            games = []
            for row in result:
                games.append(GameSummary(
                    game_id=row[0],
                    team_a=row[1],
                    team_b=row[2], 
                    status=row[3],
                    start_time=row[4],
                    detection_events_count=row[5],
                    rule_events_count=row[6]
                ))
            return games
            
    except Exception as e:
        logger.error(f"Failed to retrieve games summary: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/events/detection/stats", response_model=list[DetectionEventStats])
async def get_detection_events_stats(
    game_id: Optional[int] = Query(None, description="指定比赛ID"),
    hours_back: int = Query(24, description="统计过去N小时的数据")
):
    """获取检测事件统计"""
    try:
        query = """
        SELECT 
            event_type,
            COUNT(*) as count,
            COALESCE(AVG(confidence), 0) as avg_confidence
        FROM detection_events
        WHERE timestamp >= NOW() - make_interval(hours => :hours_back)
        """
        
        params = {"hours_back": hours_back}
        
        if game_id:
            query += " AND game_id = :game_id"
            params["game_id"] = game_id
            
        query += " GROUP BY event_type ORDER BY count DESC"
        
        with engine.connect() as conn:
            result = conn.execute(text(query), params)
            stats = []
            for row in result:
                stats.append(DetectionEventStats(
                    event_type=row[0],
                    count=row[1],
                    avg_confidence=float(row[2])
                ))
            return stats
            
    except Exception as e:
        logger.error(f"Failed to retrieve detection events stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/system/metrics")
async def get_system_metrics(
    service_name: Optional[str] = Query(None, description="指定服务名"),
    hours_back: int = Query(1, description="获取过去N小时的指标")
):
    """获取系统性能指标"""
    try:
        query = """
        SELECT 
            service_name,
            metric_name,
            AVG(metric_value) as avg_value,
            MAX(metric_value) as max_value,
            MIN(metric_value) as min_value,
            unit
        FROM system_metrics
        WHERE timestamp >= NOW() - make_interval(hours => :hours_back)
        """
        
        params = {"hours_back": hours_back}
        
        if service_name:
            query += " AND service_name = :service_name"
            params["service_name"] = service_name
            
        query += " GROUP BY service_name, metric_name, unit ORDER BY service_name, metric_name"
        
        with engine.connect() as conn:
            result = conn.execute(text(query), params)
            metrics = []
            for row in result:
                metrics.append({
                    "service_name": row[0],
                    "metric_name": row[1], 
                    "avg_value": float(row[2]),
                    "max_value": float(row[3]),
                    "min_value": float(row[4]),
                    "unit": row[5]
                })
            return {"metrics": metrics}
            
    except Exception as e:
        logger.error(f"Failed to retrieve system metrics: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/events/realtime", response_model=dict)
async def get_realtime_events(
    limit: int = Query(20, description="返回最近N条原始检测与规则事件"),
    game_id: Optional[int] = Query(None, description="指定比赛ID")
):
    try:
        # 最近 N 条 detection_events
        det_sql = """
        SELECT timestamp, event_type, player_id, confidence, raw_data
        FROM detection_events
        {where}
        ORDER BY timestamp DESC
        LIMIT :limit
        """
        where = "WHERE 1=1"
        params = {"limit": limit}
        if game_id:
            where += " AND game_id = :game_id"
            params["game_id"] = game_id
        det_sql = det_sql.format(where=where)

        # 最近 N 条 rule_events
        rule_sql = """
        SELECT timestamp, rule_type, player_id, decision, confidence, context_data
        FROM rule_events
        {where}
        ORDER BY timestamp DESC
        LIMIT :limit
        """
        rule_sql = rule_sql.format(where=where)

        with engine.connect() as conn:
            det_rows = conn.execute(text(det_sql), params).fetchall()
            rule_rows = conn.execute(text(rule_sql), params).fetchall()

        detections = []
        for r in det_rows:
            details = r[4] if isinstance(r[4], dict) else json.loads(r[4]) if r[4] else {}
            detections.append({
                "timestamp": r[0],
                "event_type": r[1],
                "player_id": r[2],
                "confidence": float(r[3]) if r[3] is not None else 0.0,
                "details": details,
            })

        rules = []
        for r in rule_rows:
            details = r[5] if isinstance(r[5], dict) else json.loads(r[5]) if r[5] else {}
            rules.append({
                "timestamp": r[0],
                "rule_type": r[1],
                "player_id": r[2],
                "decision": bool(r[3]) if r[3] is not None else False,
                "confidence": float(r[4]) if r[4] is not None else 0.0,
                "details": details,
            })

        return {"detections": detections, "rules": rules}

    except Exception as e:
        logger.error(f"Failed to retrieve realtime events: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/events/rule/summary", response_model=list[RuleEventSummary])
async def get_rule_events_summary(
    hours_back: int = Query(24, description="统计过去N小时的数据"),
    game_id: Optional[int] = Query(None, description="指定比赛ID")
):
    try:
        query = """
        SELECT 
            rule_type,
            SUM(CASE WHEN decision = TRUE THEN 1 ELSE 0 END) as violation_count,
            SUM(CASE WHEN decision = FALSE THEN 1 ELSE 0 END) as warning_count,
            COALESCE(AVG(confidence), 0) as avg_confidence
        FROM rule_events
        WHERE timestamp >= NOW() - make_interval(hours => :hours_back)
        {extra}
        GROUP BY rule_type
        ORDER BY violation_count DESC, warning_count DESC
        """
        params = {"hours_back": hours_back}
        extra = ""
        if game_id:
            extra = " AND game_id = :game_id"
            params["game_id"] = game_id
        query = query.format(extra=extra)

        with engine.connect() as conn:
            result = conn.execute(text(query), params)
            rows = result.fetchall()
            out = []
            for r in rows:
                out.append(RuleEventSummary(
                    rule_type=r[0],
                    violation_count=int(r[1]),
                    warning_count=int(r[2]),
                    avg_confidence=float(r[3])
                ))
            return out

    except Exception as e:
        logger.error(f"Failed to summarize rule events: {e}")
        raise HTTPException(status_code=500, detail=str(e))