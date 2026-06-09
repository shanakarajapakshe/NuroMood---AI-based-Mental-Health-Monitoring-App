from __future__ import annotations

import hashlib
import json
import os
import re
from datetime import date, datetime, timedelta, timezone
from typing import Any
from uuid import UUID

import torch
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from transformers import AutoModelForSequenceClassification, AutoTokenizer


ARTIFACTS_DIR = os.getenv("NUROMOOD_ARTIFACTS", "artifacts")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+psycopg://postgres:postgres@localhost:5432/nuromood")
CRISIS_CONFIDENCE_THRESHOLD = 0.85

with open(os.path.join(ARTIFACTS_DIR, "label_names.json"), "r", encoding="utf-8") as f:
    LABELS: list[str] = json.load(f)

tokenizer = AutoTokenizer.from_pretrained(ARTIFACTS_DIR)
model = AutoModelForSequenceClassification.from_pretrained(ARTIFACTS_DIR)
model.eval()

engine: Engine = create_engine(DATABASE_URL, pool_pre_ping=True)

app = FastAPI(title="NeuroMood Secure AI API", version="2.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class EncryptedJournalPayload(BaseModel):
    ciphertext: str = Field(min_length=16)
    iv: str = Field(min_length=8)
    key_version: int = 1


class AnalyzeJournalRequest(BaseModel):
    user_id: int
    encrypted_journal: EncryptedJournalPayload
    model_text: str = Field(min_length=1, max_length=4000)
    image_path: str | None = None
    client_created_at: datetime | None = None


class Trigger(BaseModel):
    category: str
    words: list[str]


class AnalyzeJournalResponse(BaseModel):
    journal_id: UUID
    primary_emotion: str
    confidence: float
    confidence_percent: float
    scores: dict[str, float]
    top_emotions: list[dict[str, float | str]]
    triggers: list[Trigger]
    sentiment_shift: dict[str, Any]
    coping_plan: dict[str, Any]
    streak: dict[str, int]
    crisis_flag: bool
    crisis_signal: str | None = None


TRIGGER_KEYWORDS: dict[str, set[str]] = {
    "work": {"work", "office", "boss", "deadline", "meeting", "job", "career", "exam", "assignment"},
    "relationship": {"friend", "family", "mother", "father", "partner", "breakup", "love", "relationship"},
    "health": {"pain", "sick", "ill", "doctor", "sleep", "tired", "anxiety", "stress", "panic"},
    "finance": {"money", "salary", "debt", "loan", "rent", "bills", "finance", "payment"},
}

CRISIS_TERMS = {
    "suicide",
    "kill myself",
    "end my life",
    "self harm",
    "hurt myself",
    "can't go on",
    "no reason to live",
    "i want to die",
    "want to die",
    "hopeless",
    "worthless",
    "cut myself",
}


class CrisisEventLogRequest(BaseModel):
    user_id: int
    journal_id: UUID | None = None
    signal: str = "ui_interaction"
    confidence: float = 0
    user_action: str = "shown"


class EntitlementUpdateRequest(BaseModel):
    tier: str = "free"
    premium_until: datetime | None = None


def build_entitlement(tier: str, premium_until: datetime | None) -> dict[str, Any]:
    if premium_until and premium_until < datetime.now(timezone.utc):
        tier = "free"
    is_premium = tier == "premium"
    return {
        "tier": tier,
        "is_premium": is_premium,
        "premium_until": premium_until.isoformat() if premium_until else None,
        "features": {
            "charts_days": 30 if is_premium else 7,
            "voice_journaling": is_premium,
            "clinical_export": is_premium,
            "advanced_triggers": is_premium,
        },
    }


def analyze_emotion(text_value: str) -> tuple[str, float, dict[str, float]]:
    encoded = tokenizer([text_value], truncation=True, padding=True, max_length=160, return_tensors="pt")
    with torch.no_grad():
        logits = model(**encoded).logits
    probabilities = torch.softmax(logits, dim=1).numpy()[0]
    raw_scores = {LABELS[i]: float(probabilities[i]) for i in range(len(LABELS))}
    scores = normalize_emotion_scores(raw_scores, text_value)
    primary = max(scores, key=scores.get)
    return primary, scores[primary], scores


def normalize_emotion_scores(raw_scores: dict[str, float], text_value: str) -> dict[str, float]:
    lower_text = text_value.lower()
    scores = dict(raw_scores)
    fear_score = scores.get("fear", 0.0)
    anxiety_boost = 0.12 if any(word in lower_text for word in ["anxiety", "anxious", "panic", "worried", "stress"]) else 0.0
    scores["anxiety"] = min(1.0, fear_score + anxiety_boost)
    strongest = max(raw_scores.values()) if raw_scores else 0.0
    scores["neutral"] = max(0.0, min(1.0, 1.0 - strongest)) if strongest < 0.55 else 0.0
    return scores


def top_emotions(scores: dict[str, float], limit: int = 3) -> list[dict[str, float | str]]:
    return [
        {"emotion": emotion, "confidence": confidence, "confidence_percent": round(confidence * 100, 2)}
        for emotion, confidence in sorted(scores.items(), key=lambda item: item[1], reverse=True)[:limit]
    ]


def extract_triggers(text_value: str) -> list[dict[str, Any]]:
    lower_text = text_value.lower()
    found: list[dict[str, Any]] = []
    for category, keywords in TRIGGER_KEYWORDS.items():
        words = sorted(word for word in keywords if word in lower_text)
        if words:
            found.append({"category": category, "words": words})
    return found


def split_journal_segments(text_value: str) -> list[str]:
    segments = [part.strip() for part in re.split(r"(?<=[.!?])\s+|\n+", text_value) if part.strip()]
    if not segments and text_value.strip():
        segments = [text_value.strip()]
    return segments[:8]


def emotion_valence(emotion: str) -> str:
    if emotion in {"joy", "love"}:
        return "positive"
    if emotion in {"sadness", "anger", "fear", "anxiety"}:
        return "negative"
    return "neutral"


def detect_sentiment_shift(text_value: str) -> dict[str, Any]:
    segments = split_journal_segments(text_value)
    analyzed: list[dict[str, Any]] = []
    for index, segment in enumerate(segments):
        emotion, confidence, _scores = analyze_emotion(segment)
        analyzed.append(
            {
                "index": index,
                "text_preview": segment[:120],
                "emotion": emotion,
                "confidence": confidence,
                "valence": emotion_valence(emotion),
            }
        )
    if len(analyzed) < 2:
        return {"shift_detected": False, "direction": "stable", "segments": analyzed}

    first = analyzed[0]
    last = analyzed[-1]
    shift_detected = first["valence"] != last["valence"] or first["emotion"] != last["emotion"]
    direction = f"{first['valence']}_to_{last['valence']}" if shift_detected else "stable"
    return {"shift_detected": shift_detected, "direction": direction, "segments": analyzed}


def detect_crisis(text_value: str, primary_emotion: str, confidence: float) -> tuple[bool, str | None]:
    lower_text = text_value.lower()
    matched_term = next((term for term in CRISIS_TERMS if term in lower_text), None)
    severe_negative = primary_emotion in {"sadness", "fear", "anger"} and confidence >= CRISIS_CONFIDENCE_THRESHOLD
    if matched_term:
        return True, f"keyword:{matched_term}"
    if severe_negative:
        return True, f"high_confidence_negative:{primary_emotion}"
    return False, None


def coping_plan(emotion: str) -> dict[str, Any]:
    plans: dict[str, dict[str, Any]] = {
        "anger": {
            "title": "Cool-down breathing",
            "message": "Try a slow 4-4-6 breath cycle before replying or making a decision.",
            "exercise": "breathing_4_4_6",
            "steps": ["Inhale for 4 seconds", "Hold for 4 seconds", "Exhale for 6 seconds", "Repeat 5 times"],
        },
        "fear": {
            "title": "Grounding reset",
            "message": "Name what is around you to bring your attention back to the present.",
            "exercise": "grounding_5_4_3_2_1",
            "steps": ["Notice 5 things you see", "4 things you feel", "3 things you hear", "2 things you smell", "1 thing you taste"],
        },
        "anxiety": {
            "title": "Steady breath",
            "message": "A short breathing cycle can lower the intensity of anxious thoughts.",
            "exercise": "breathing_4_4_6",
            "steps": ["Inhale gently", "Hold briefly", "Exhale longer than you inhale"],
        },
        "sadness": {
            "title": "One small care action",
            "message": "Choose one tiny action: drink water, message someone safe, or step outside for two minutes.",
            "exercise": "micro_care",
            "steps": ["Drink water", "Relax your shoulders", "Write one thing you need right now"],
        },
        "joy": {
            "title": "Savor the moment",
            "message": "Write one sentence about what made this moment good so you can revisit it later.",
            "exercise": "savoring",
            "steps": ["Name the good moment", "Notice where you feel it", "Choose one way to extend it"],
        },
    }
    return plans.get(
        emotion,
        {
            "title": "Gentle check-in",
            "message": "Take one minute to notice your body, breath, and surroundings.",
            "exercise": "breathing_4_4_6",
            "steps": ["Inhale", "Pause", "Exhale slowly"],
        },
    )


def update_streak(conn, user_id: int, created_on: date) -> dict[str, int]:
    row = conn.execute(
        text("SELECT current_streak, longest_streak, last_journal_date FROM user_streaks WHERE user_id=:user_id FOR UPDATE"),
        {"user_id": user_id},
    ).mappings().first()

    if row is None:
        current_streak = 1
        longest_streak = 1
    else:
        last_date = row["last_journal_date"]
        if last_date == created_on:
            current_streak = int(row["current_streak"])
        elif last_date == created_on - timedelta(days=1):
            current_streak = int(row["current_streak"]) + 1
        else:
            current_streak = 1
        longest_streak = max(int(row["longest_streak"]), current_streak)

    conn.execute(
        text(
            """
            INSERT INTO user_streaks (user_id, current_streak, longest_streak, last_journal_date, updated_at)
            VALUES (:user_id, :current_streak, :longest_streak, :last_journal_date, now())
            ON CONFLICT (user_id) DO UPDATE SET
              current_streak = EXCLUDED.current_streak,
              longest_streak = EXCLUDED.longest_streak,
              last_journal_date = EXCLUDED.last_journal_date,
              updated_at = now()
            """
        ),
        {
            "user_id": user_id,
            "current_streak": current_streak,
            "longest_streak": longest_streak,
            "last_journal_date": created_on,
        },
    )
    return {"current": current_streak, "longest": longest_streak}


@app.post("/analyze-journal", response_model=AnalyzeJournalResponse)
def analyze_journal(payload: AnalyzeJournalRequest) -> AnalyzeJournalResponse:
    primary, confidence, scores = analyze_emotion(payload.model_text)
    triggers = extract_triggers(payload.model_text)
    sentiment_shift = detect_sentiment_shift(payload.model_text)
    crisis_flag, crisis_signal = detect_crisis(payload.model_text, primary, confidence)
    created_at = payload.client_created_at or datetime.now(timezone.utc)
    model_text_hash = hashlib.sha256(payload.model_text.encode("utf-8")).hexdigest()

    try:
        with engine.begin() as conn:
            inserted = conn.execute(
                text(
                    """
                    INSERT INTO journals_secure (
                      user_id, encrypted_text, encryption_iv, encryption_key_version, model_text_hash,
                      primary_emotion, confidence, emotion_scores, trigger_words, trigger_categories,
                      sentiment_shifts, image_path, created_at
                    )
                    VALUES (
                      :user_id, :encrypted_text, :encryption_iv, :encryption_key_version, :model_text_hash,
                      :primary_emotion, :confidence, CAST(:emotion_scores AS jsonb),
                      CAST(:trigger_words AS jsonb), CAST(:trigger_categories AS jsonb),
                      CAST(:sentiment_shifts AS jsonb), :image_path, :created_at
                    )
                    RETURNING id
                    """
                ),
                {
                    "user_id": payload.user_id,
                    "encrypted_text": payload.encrypted_journal.ciphertext,
                    "encryption_iv": payload.encrypted_journal.iv,
                    "encryption_key_version": payload.encrypted_journal.key_version,
                    "model_text_hash": model_text_hash,
                    "primary_emotion": primary,
                    "confidence": confidence,
                    "emotion_scores": json.dumps(scores),
                    "trigger_words": json.dumps(triggers),
                    "trigger_categories": json.dumps([item["category"] for item in triggers]),
                    "sentiment_shifts": json.dumps(sentiment_shift),
                    "image_path": payload.image_path,
                    "created_at": created_at,
                },
            ).mappings().one()
            streak = update_streak(conn, payload.user_id, created_at.date())

            if crisis_flag:
                conn.execute(
                    text(
                        """
                        INSERT INTO crisis_events (user_id, journal_id, signal, confidence)
                        VALUES (:user_id, :journal_id, :signal, :confidence)
                        """
                    ),
                    {
                        "user_id": payload.user_id,
                        "journal_id": inserted["id"],
                        "signal": crisis_signal or "unknown",
                        "confidence": confidence,
                    },
                )
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Could not save journal analysis") from exc

    return AnalyzeJournalResponse(
        journal_id=inserted["id"],
        primary_emotion=primary,
        confidence=confidence,
        confidence_percent=round(confidence * 100, 2),
        scores=scores,
        top_emotions=top_emotions(scores),
        triggers=[Trigger(**item) for item in triggers],
        sentiment_shift=sentiment_shift,
        coping_plan=coping_plan(primary),
        streak=streak,
        crisis_flag=crisis_flag,
        crisis_signal=crisis_signal,
    )


@app.get("/analytics/{user_id}")
def analytics(user_id: int, days: int = 30) -> dict[str, Any]:
    with engine.begin() as conn:
        trend_rows = conn.execute(
            text(
                """
                SELECT date_trunc('day', created_at)::date AS day,
                       primary_emotion,
                       AVG(confidence)::float AS avg_confidence,
                       COUNT(*)::int AS total
                FROM journals_secure
                WHERE user_id=:user_id
                  AND is_deleted=false
                  AND created_at >= now() - (:days || ' days')::interval
                GROUP BY day, primary_emotion
                ORDER BY day
                """
            ),
            {"user_id": user_id, "days": days},
        ).mappings().all()
        trigger_rows = conn.execute(
            text(
                """
                SELECT category, COUNT(*)::int AS total
                FROM journals_secure, jsonb_array_elements_text(trigger_categories) AS category
                WHERE user_id=:user_id
                  AND is_deleted=false
                  AND created_at >= now() - (:days || ' days')::interval
                GROUP BY category
                ORDER BY total DESC
                """
            ),
            {"user_id": user_id, "days": days},
        ).mappings().all()
    return {"trend": [dict(row) for row in trend_rows], "trigger_breakdown": [dict(row) for row in trigger_rows]}


@app.post("/crisis-events")
def log_crisis_event(payload: CrisisEventLogRequest) -> dict[str, bool]:
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                INSERT INTO crisis_events (user_id, journal_id, signal, confidence, user_action)
                VALUES (:user_id, :journal_id, :signal, :confidence, :user_action)
                """
            ),
            {
                "user_id": payload.user_id,
                "journal_id": payload.journal_id,
                "signal": payload.signal,
                "confidence": payload.confidence,
                "user_action": payload.user_action,
            },
        )
    return {"success": True}


@app.get("/entitlements/{user_id}")
def get_entitlements(user_id: int) -> dict[str, Any]:
    with engine.begin() as conn:
      row = conn.execute(
          text("SELECT subscription_tier, premium_until FROM users WHERE id=:user_id"),
          {"user_id": user_id},
      ).mappings().first()
    if row is None:
        return build_entitlement("free", None)
    return build_entitlement(row["subscription_tier"] or "free", row["premium_until"])


@app.post("/entitlements/{user_id}")
def update_entitlements(user_id: int, payload: EntitlementUpdateRequest) -> dict[str, Any]:
    if payload.tier not in {"free", "premium"}:
        raise HTTPException(status_code=400, detail="Invalid tier")
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE users SET subscription_tier=:tier, premium_until=:premium_until WHERE id=:user_id"),
            {"tier": payload.tier, "premium_until": payload.premium_until, "user_id": user_id},
        )
    return {"success": True, "entitlement": build_entitlement(payload.tier, payload.premium_until)}
