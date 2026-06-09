from flask import Flask, request, jsonify, Response
from flask_cors import CORS
import sqlite3
from datetime import datetime
import re
import torch, json
from werkzeug.security import generate_password_hash, check_password_hash
from transformers import AutoTokenizer, AutoModelForSequenceClassification

# -------------------- Model Setup --------------------
ARTIFACTS = "artifacts"
with open(f"{ARTIFACTS}/label_names.json","r") as f:
    LABELS = json.load(f)

tok = AutoTokenizer.from_pretrained(ARTIFACTS)
model = AutoModelForSequenceClassification.from_pretrained(ARTIFACTS)
model.eval()

# -------------------- Flask Setup --------------------
app = Flask(__name__)
CORS(app)  # allow Flutter web/mobile to call API

DB_FILE = "database/nuromood.db"

TRIGGER_KEYWORDS = {
    "work": ["work", "office", "boss", "deadline", "meeting", "job", "exam", "assignment"],
    "relationship": ["friend", "family", "mother", "father", "partner", "breakup", "love"],
    "health": ["pain", "sick", "doctor", "sleep", "tired", "anxiety", "stress", "panic"],
    "finance": ["money", "salary", "debt", "loan", "rent", "bills", "payment"],
}

CRISIS_TERMS = [
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
]

NEGATED_POSITIVE_PHRASES = [
    "not happy",
    "not good",
    "not okay",
    "not fine",
    "not feeling good",
    "don't feel good",
    "dont feel good",
    "doesn't feel good",
    "doesnt feel good",
    "no happiness",
]

EMOTION_KEYWORDS = {
    "joy": [
        "happy", "glad", "calm", "peaceful", "relaxed", "proud", "grateful", "excited",
        "hopeful", "good", "great", "better", "fun", "smile", "joy", "satisfied",
        "beautiful", "favorite", "laughed", "laugh", "lucky", "safe", "surprised me",
        "sathutu", "hodai", "hondai", "happy wage", "relax",
    ],
    "sadness": [
        "sad", "lonely", "alone", "hurt", "cry", "cried", "crying", "depressed", "empty",
        "tired", "exhausted", "hopeless", "miss", "grief", "upset", "low", "down",
        "duka", "dukai", "palui", "mahansi",
    ],
    "anger": [
        "angry", "mad", "furious", "annoyed", "irritated", "hate", "frustrated",
        "unfair", "rage", "blame", "argue", "fight", "pissed", "stressful",
        "tharaha", "taraha", "epa wela", "kenti",
    ],
    "fear": [
        "afraid", "scared", "fear", "terrified", "unsafe", "nervous", "worried",
        "worry", "panic", "threat", "danger", "doubt", "confused",
        "tight feeling", "tight chest", "make ends meet", "bank account",
        "bayai", "baya", "kalabala",
    ],
    "anxiety": [
        "anxiety", "anxious", "panic", "overthinking", "overthink", "stressed",
        "stress", "pressure", "tense", "restless", "can't sleep", "cant sleep",
        "nervous", "worried", "worry", "exam", "deadline", "bills", "repair",
        "bank account", "balance", "tight feeling", "tight chest", "make ends meet",
    ],
    "love": [
        "love", "loved", "romantic", "caring", "kind", "close", "hug", "miss you",
        "relationship", "partner", "family", "friend", "safe to have", "in my life",
        "talked for hours", "favorite dinner", "adarei", "aadarei",
    ],
    "surprise": [
        "surprised", "shock", "shocked", "unexpected", "suddenly", "wow", "amazed",
        "can't believe", "cant believe", "pudumai",
    ],
}

NEGATION_WORDS = {"not", "no", "never", "didnt", "didn't", "dont", "don't", "isnt", "isn't", "wasnt", "wasn't", "naha", "nehe", "na"}
INTENSIFIERS = {"very", "really", "so", "too", "extremely", "godak", "hari", "hondatama"}

# -------------------- Database Helpers --------------------
def init_db():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    # Users
    c.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            created_at TEXT DEFAULT (datetime('now'))
        )
    """)
    _ensure_column(c, "users", "password_hash", "TEXT")
    _ensure_column(c, "users", "auth_provider", "TEXT DEFAULT 'password'")
    _ensure_column(c, "users", "last_login_at", "TEXT")
    _ensure_column(c, "users", "subscription_tier", "TEXT DEFAULT 'free'")
    _ensure_column(c, "users", "premium_until", "TEXT")

    # Journals (soft delete)
    c.execute("""
        CREATE TABLE IF NOT EXISTS journals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            text TEXT NOT NULL,
            mood TEXT NOT NULL,
            date TEXT DEFAULT (datetime('now')),
            image_path TEXT,
            is_deleted INTEGER DEFAULT 0,
            FOREIGN KEY(user_id) REFERENCES users(id)
            )
    """)
    _ensure_column(c, "journals", "encrypted_text", "TEXT")
    _ensure_column(c, "journals", "encryption_iv", "TEXT")
    _ensure_column(c, "journals", "encryption_key_version", "INTEGER DEFAULT 1")
    _ensure_column(c, "journals", "confidence", "REAL DEFAULT 0")
    _ensure_column(c, "journals", "emotion_scores", "TEXT DEFAULT '{}'")
    _ensure_column(c, "journals", "trigger_categories", "TEXT DEFAULT '[]'")
    _ensure_column(c, "journals", "sentiment_shifts", "TEXT DEFAULT '{}'")
    _ensure_column(c, "journals", "crisis_flag", "INTEGER DEFAULT 0")
    _ensure_column(c, "journals", "deleted_at", "TEXT")

    c.execute("""
        CREATE TABLE IF NOT EXISTS crisis_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            journal_id INTEGER,
            signal TEXT NOT NULL,
            confidence REAL NOT NULL,
            user_action TEXT DEFAULT 'shown',
            created_at TEXT DEFAULT (datetime('now'))
        )
    """)
    c.execute("""
        CREATE TABLE IF NOT EXISTS user_streaks (
            user_id INTEGER PRIMARY KEY,
            current_streak INTEGER DEFAULT 0,
            longest_streak INTEGER DEFAULT 0,
            last_journal_date TEXT,
            updated_at TEXT DEFAULT (datetime('now')),
            FOREIGN KEY(user_id) REFERENCES users(id)
        )
    """)
    c.execute("""
        CREATE TABLE IF NOT EXISTS user_badges (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            badge_id TEXT NOT NULL,
            unlocked_at TEXT DEFAULT (datetime('now')),
            UNIQUE(user_id, badge_id),
            FOREIGN KEY(user_id) REFERENCES users(id)
        )
    """)
    conn.commit()
    conn.close()

def _ensure_column(cursor, table, column, definition):
    cursor.execute(f"PRAGMA table_info({table})")
    columns = [row[1] for row in cursor.fetchall()]
    if column not in columns:
        cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")

def get_db_connection():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn

def purge_expired_trash(cursor):
    cursor.execute(
        "DELETE FROM journals WHERE is_deleted=1 AND deleted_at IS NOT NULL AND datetime(deleted_at) < datetime('now', '-30 days')"
    )

def anonymize_for_model(text):
    text = re.sub(r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", "[email]", text, flags=re.I)
    text = re.sub(r"\+?\d[\d\s-]{7,}\d", "[phone]", text)
    text = re.sub(r"\b\d{9}[vVxX]\b|\b\d{12}\b", "[id]", text)
    return text

def analyze_emotion(text):
    enc = tok([text], truncation=True, padding=True, max_length=160, return_tensors='pt')
    with torch.no_grad():
        logits = model(**enc).logits
    probs = torch.softmax(logits, dim=1).numpy()[0]
    raw_scores = {LABELS[i]: float(p) for i, p in enumerate(probs)}
    scores = normalize_emotion_scores(raw_scores, text)
    pred = max(scores, key=scores.get)
    return pred, float(scores[pred]), scores

def normalize_emotion_scores(raw_scores, text):
    lower = text.lower()
    tokens = re.findall(r"[a-zA-Z']+|[අ-෿]+", lower)
    token_set = set(tokens)
    scores = {emotion: float(raw_scores.get(emotion, 0.0)) * 0.42 for emotion in LABELS}
    scores["anxiety"] = scores.get("fear", 0.0) * 0.65
    scores["neutral"] = 0.0
    evidence = {emotion: 0 for emotion in EMOTION_KEYWORDS}

    for emotion, keywords in EMOTION_KEYWORDS.items():
        boost = 0.0
        for keyword in keywords:
            keyword_lower = keyword.lower()
            matched = keyword_lower in lower if " " in keyword_lower or "'" in keyword_lower else keyword_lower in token_set
            if not matched:
                continue
            keyword_tokens = keyword_lower.split()
            first_token = keyword_tokens[0] if keyword_tokens else keyword_lower
            first_index = tokens.index(first_token) if first_token in tokens else -1
            window = tokens[max(0, first_index - 3):first_index] if first_index >= 0 else []
            negated = any(word in NEGATION_WORDS for word in window)
            intensity = 1.25 if any(word in INTENSIFIERS for word in window) else 1.0
            if not negated:
                evidence[emotion] = evidence.get(emotion, 0) + 1
            boost += (-0.28 if negated else 0.36 * intensity)
        scores[emotion] = max(0.0, scores.get(emotion, 0.0) + boost)

    positive_evidence = evidence.get("joy", 0) + evidence.get("love", 0)
    anxiety_evidence = evidence.get("anxiety", 0) + evidence.get("fear", 0)
    sadness_evidence = evidence.get("sadness", 0)
    anger_evidence = evidence.get("anger", 0)
    if positive_evidence >= 3:
        scores["neutral"] = 0.0
        scores["joy"] = max(scores.get("joy", 0.0), 0.95)
        if evidence.get("love", 0) >= 2:
            scores["love"] = max(scores.get("love", 0.0), 0.80)
    if anxiety_evidence >= 2:
        scores["neutral"] = 0.0
        scores["anxiety"] = max(scores.get("anxiety", 0.0), 1.05)
        scores["fear"] = max(scores.get("fear", 0.0), 0.45)
    if sadness_evidence >= 2:
        scores["neutral"] = 0.0
        scores["sadness"] = max(scores.get("sadness", 0.0), 0.95)
    if anger_evidence >= 2:
        scores["neutral"] = 0.0
        scores["anger"] = max(scores.get("anger", 0.0), 0.95)

    negative_total = scores.get("sadness", 0) + scores.get("anger", 0) + scores.get("fear", 0) + scores.get("anxiety", 0)
    positive_total = scores.get("joy", 0) + scores.get("love", 0)
    if not tokens or (max(scores.values()) < 0.35 and negative_total < 0.45 and positive_total < 0.45):
        scores["neutral"] = 0.42
    if any(phrase in lower for phrase in ["nothing special", "normal day", "same as usual", "just okay", "fine", "ok", "okay"]):
        scores = {emotion: value * 0.35 for emotion, value in scores.items()}
        scores["neutral"] = max(scores["neutral"], 1.0)
    if any(phrase in lower for phrase in NEGATED_POSITIVE_PHRASES):
        scores["joy"] = scores.get("joy", 0) * 0.15
        scores["neutral"] = scores.get("neutral", 0) * 0.35
        scores["sadness"] = max(scores.get("sadness", 0), 0.95)
    if scores.get("anxiety", 0) > 0.35:
        scores["fear"] = max(0.0, scores.get("fear", 0) * 0.72)
    if any(word in token_set for word in ["dukai", "duka", "palui"]):
        scores["sadness"] = max(scores.get("sadness", 0), 1.0)
        scores["anger"] = scores.get("anger", 0) * 0.35
    if any(word in token_set for word in ["bayai", "baya", "kalabala"]):
        scores["fear"] = max(scores.get("fear", 0), 0.85)
        scores["anger"] = scores.get("anger", 0) * 0.35
    if any(word in token_set for word in ["stress", "stressed", "overthinking", "overthink", "pressure"]):
        scores["anxiety"] = max(scores.get("anxiety", 0), 0.9)
        scores["anger"] = scores.get("anger", 0) * 0.5

    if positive_evidence >= 3:
        scores["neutral"] = scores.get("neutral", 0) * 0.12
        scores["joy"] = max(scores.get("joy", 0), 1.15)
        if evidence.get("love", 0) >= 2:
            scores["love"] = max(scores.get("love", 0), 0.95)
    if anxiety_evidence >= 2:
        scores["neutral"] = scores.get("neutral", 0) * 0.20
        scores["anxiety"] = max(scores.get("anxiety", 0), 1.15)

    total = sum(scores.values()) or 1.0
    return {emotion: value / total for emotion, value in scores.items()}

def top_emotions(scores, limit=3):
    return [
        {"emotion": emotion, "confidence": confidence, "confidence_percent": round(confidence * 100, 2)}
        for emotion, confidence in sorted(scores.items(), key=lambda item: item[1], reverse=True)[:limit]
    ]

def extract_triggers(text):
    lower = text.lower()
    triggers = []
    for category, words in TRIGGER_KEYWORDS.items():
        matched = sorted({word for word in words if word in lower})
        if matched:
            triggers.append({"category": category, "words": matched})
    return triggers

def split_journal_segments(text):
    segments = [part.strip() for part in re.split(r"(?<=[.!?])\s+|\n+", text) if part.strip()]
    if not segments:
        segments = [text.strip()] if text.strip() else []
    return segments[:8]

def emotion_valence(emotion):
    if emotion in {"joy", "love"}:
        return "positive"
    if emotion in {"sadness", "anger", "fear", "anxiety"}:
        return "negative"
    return "neutral"

def detect_sentiment_shift(text):
    segments = split_journal_segments(text)
    analyzed = []
    for index, segment in enumerate(segments):
        emotion, confidence, _scores = analyze_emotion(segment)
        analyzed.append({
            "index": index,
            "text_preview": segment[:120],
            "emotion": emotion,
            "confidence": confidence,
            "valence": emotion_valence(emotion),
        })
    if len(analyzed) < 2:
        return {"shift_detected": False, "direction": "stable", "segments": analyzed}

    first = analyzed[0]
    last = analyzed[-1]
    shift_detected = first["valence"] != last["valence"] or first["emotion"] != last["emotion"]
    direction = f"{first['valence']}_to_{last['valence']}" if shift_detected else "stable"
    return {"shift_detected": shift_detected, "direction": direction, "segments": analyzed}

def detect_crisis(text, emotion, confidence):
    lower = text.lower()
    for term in CRISIS_TERMS:
        if term in lower:
            return True, f"keyword:{term}"
    return False, None

def coping_plan(emotion):
    plans = {
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
        "love": {
            "title": "Connection note",
            "message": "Consider sending a kind message or saving this memory in your journal.",
            "exercise": "connection",
            "steps": ["Name the person or moment", "Write what mattered", "Choose a small caring action"],
        },
    }
    return plans.get(emotion, {
        "title": "Gentle check-in",
        "message": "Take one minute to notice your body, breath, and surroundings.",
        "exercise": "breathing_4_4_6",
        "steps": ["Inhale", "Pause", "Exhale slowly"],
    })

def update_user_streak(cursor, user_id):
    today = datetime.now().date()
    cursor.execute("SELECT current_streak, longest_streak, last_journal_date FROM user_streaks WHERE user_id=?", (user_id,))
    row = cursor.fetchone()
    if not row:
        current = 1
        longest = 1
    else:
        last = datetime.fromisoformat(row["last_journal_date"]).date() if row["last_journal_date"] else None
        if last == today:
            current = row["current_streak"]
        elif last and (today - last).days == 1:
            current = row["current_streak"] + 1
        else:
            current = 1
        longest = max(row["longest_streak"], current)
    cursor.execute(
        """
        INSERT INTO user_streaks (user_id, current_streak, longest_streak, last_journal_date, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
            current_streak=excluded.current_streak,
            longest_streak=excluded.longest_streak,
            last_journal_date=excluded.last_journal_date,
            updated_at=excluded.updated_at
        """,
        (user_id, current, longest, today.isoformat(), datetime.now().isoformat()),
    )
    return {"current": current, "longest": longest}

def unlock_badges(cursor, user_id, streak):
    cursor.execute("SELECT COUNT(*) AS total FROM journals WHERE user_id=? AND is_deleted=0", (user_id,))
    total_entries = cursor.fetchone()["total"]
    cursor.execute(
        "SELECT mood FROM journals WHERE user_id=? AND is_deleted=0 ORDER BY date DESC LIMIT 3",
        (user_id,),
    )
    recent_moods = [row["mood"] for row in cursor.fetchall()]
    candidates = []
    if total_entries >= 1:
        candidates.append("first_entry")
    if streak["longest"] >= 7:
        candidates.append("seven_day_streak")
    if streak["longest"] >= 30:
        candidates.append("thirty_day_streak")
    if total_entries >= 20:
        candidates.append("deep_reflector")
    if len(recent_moods) == 3 and all(mood in {"joy", "love", "surprise"} for mood in recent_moods):
        candidates.append("positive_flow")
    for badge_id in candidates:
        cursor.execute(
            "INSERT OR IGNORE INTO user_badges (user_id, badge_id, unlocked_at) VALUES (?, ?, ?)",
            (user_id, badge_id, datetime.now().isoformat()),
        )
    cursor.execute("SELECT badge_id, unlocked_at FROM user_badges WHERE user_id=? ORDER BY unlocked_at DESC", (user_id,))
    return [dict(row) for row in cursor.fetchall()]

# -------------------- User Routes --------------------
@app.route("/register", methods=["POST"])
def register():
    data = request.json
    email = data.get("email")
    password = data.get("password")
    if not email or not password:
        return jsonify({"success": False, "message": "Email and password are required"}), 400
    password_hash = generate_password_hash(password)
    conn = get_db_connection()
    c = conn.cursor()
    try:
        c.execute(
            "INSERT INTO users (email, password, password_hash, auth_provider) VALUES (?, ?, ?, ?)",
            (email, "", password_hash, "password"),
        )
        conn.commit()
        user_id = c.lastrowid
    except sqlite3.IntegrityError:
        conn.close()
        return jsonify({"success": False, "message": "Email already exists"}), 400
    conn.close()
    return jsonify({"success": True, "user_id": user_id})

@app.route("/login", methods=["POST"])
def login():
    data = request.json
    email = data.get("email")
    password = data.get("password")
    conn = get_db_connection()
    c = conn.cursor()
    c.execute("SELECT * FROM users WHERE email=?", (email,))
    user = c.fetchone()
    valid = False
    if user:
        stored_hash = user["password_hash"] if "password_hash" in user.keys() else None
        legacy_password = user["password"] if "password" in user.keys() else None
        if stored_hash:
            valid = check_password_hash(stored_hash, password)
        elif legacy_password == password:
            valid = True
            c.execute(
                "UPDATE users SET password_hash=?, password='' WHERE id=?",
                (generate_password_hash(password), user["id"]),
            )
        if valid:
            c.execute("UPDATE users SET last_login_at=? WHERE id=?", (datetime.now().isoformat(), user["id"]))
            conn.commit()
    conn.close()
    if user and valid:
        return jsonify({
            "success": True,
            "user_id": user["id"],
            "subscription_tier": user["subscription_tier"] if "subscription_tier" in user.keys() else "free",
        })
    return jsonify({"success": False, "message": "Invalid email or password"}), 401

def user_entitlement(cursor, user_id):
    cursor.execute("SELECT subscription_tier, premium_until FROM users WHERE id=?", (user_id,))
    user = cursor.fetchone()
    tier = user["subscription_tier"] if user and user["subscription_tier"] else "free"
    premium_until = user["premium_until"] if user else None
    if premium_until:
        try:
            if datetime.fromisoformat(premium_until) < datetime.now():
                tier = "free"
        except ValueError:
            tier = "free"
    is_premium = tier == "premium"
    return {
        "tier": tier,
        "is_premium": is_premium,
        "premium_until": premium_until,
        "features": {
            "charts_days": 30 if is_premium else 7,
            "voice_journaling": is_premium,
            "clinical_export": is_premium,
            "advanced_triggers": is_premium,
        },
    }

@app.route("/entitlements/<int:user_id>", methods=["GET"])
def get_entitlements(user_id):
    conn = get_db_connection()
    c = conn.cursor()
    entitlement = user_entitlement(c, user_id)
    conn.close()
    return jsonify(entitlement)

@app.route("/entitlements/<int:user_id>", methods=["POST"])
def update_entitlements(user_id):
    data = request.json or {}
    tier = data.get("tier", "free")
    if tier not in {"free", "premium"}:
        return jsonify({"success": False, "message": "Invalid tier"}), 400
    conn = get_db_connection()
    c = conn.cursor()
    c.execute(
        "UPDATE users SET subscription_tier=?, premium_until=? WHERE id=?",
        (tier, data.get("premium_until"), user_id),
    )
    conn.commit()
    entitlement = user_entitlement(c, user_id)
    conn.close()
    return jsonify({"success": True, "entitlement": entitlement})

# -------------------- Journal Routes --------------------
@app.route("/journals/<int:user_id>", methods=["GET"])
def get_journals(user_id):
    conn = get_db_connection()
    c = conn.cursor()
    purge_expired_trash(c)
    conn.commit()
    c.execute("SELECT * FROM journals WHERE user_id=? AND is_deleted=0 ORDER BY date DESC", (user_id,))
    journals = [dict(row) for row in c.fetchall()]
    conn.close()
    return jsonify(journals)

@app.route("/journals/<int:user_id>/trash", methods=["GET"])
def get_trash(user_id):
    conn = get_db_connection()
    c = conn.cursor()
    purge_expired_trash(c)
    conn.commit()
    c.execute(
        """
        SELECT * FROM journals
        WHERE user_id=? AND is_deleted=1
          AND (deleted_at IS NULL OR datetime(deleted_at) >= datetime('now', '-30 days'))
        ORDER BY deleted_at DESC, date DESC
        """,
        (user_id,),
    )
    trash = [dict(row) for row in c.fetchall()]
    conn.close()
    return jsonify(trash)

@app.route("/journals/<int:user_id>", methods=["POST"])
def add_journal(user_id):
    data = request.json
    encrypted = data.get("encrypted_journal") or {}
    text = data.get("text") if not encrypted else "[encrypted]"
    mood = data.get("mood")
    confidence = float(data.get("confidence", 0) or 0)
    scores = json.dumps(data.get("scores", {}))
    triggers = json.dumps(data.get("triggers", []))
    date = datetime.now().isoformat()
    conn = get_db_connection()
    c = conn.cursor()
    c.execute(
        """
        INSERT INTO journals (
            user_id, text, mood, date, encrypted_text, encryption_iv,
            encryption_key_version, confidence, emotion_scores, trigger_categories,
            image_path
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            user_id,
            text,
            mood,
            date,
            encrypted.get("ciphertext"),
            encrypted.get("iv"),
            encrypted.get("key_version", 1),
            confidence,
            scores,
            triggers,
            data.get("image_path"),
        )
    )
    streak = update_user_streak(c, user_id)
    badges = unlock_badges(c, user_id, streak)
    conn.commit()
    conn.close()
    return jsonify({"success": True, "streak": streak, "badges": badges})

@app.route("/journals/<int:user_id>/<int:journal_id>", methods=["DELETE"])
def move_to_trash(user_id, journal_id):
    conn = get_db_connection()
    c = conn.cursor()
    c.execute(
        "UPDATE journals SET is_deleted=1, deleted_at=? WHERE id=? AND user_id=?",
        (datetime.now().isoformat(), journal_id, user_id),
    )
    conn.commit()
    conn.close()
    return jsonify({"success": True})

@app.route("/journals/<int:user_id>/<int:journal_id>/restore", methods=["POST"])
def restore_journal(user_id, journal_id):
    conn = get_db_connection()
    c = conn.cursor()
    c.execute("UPDATE journals SET is_deleted=0, deleted_at=NULL WHERE id=? AND user_id=?", (journal_id, user_id))
    conn.commit()
    conn.close()
    return jsonify({"success": True})

@app.route("/journals/<int:user_id>/<int:journal_id>", methods=["PUT"])
def update_journal(user_id, journal_id):
    data = request.json
    text = data.get("text", "")
    mood = data.get("mood")
    encrypted = data.get("encrypted_journal") or {}
    conn = get_db_connection()
    c = conn.cursor()
    if encrypted:
        c.execute(
            """
            UPDATE journals
            SET text=?, mood=?, encrypted_text=?, encryption_iv=?, encryption_key_version=?,
                image_path=?, date=?
            WHERE id=? AND user_id=?
            """,
            (
                "[encrypted]",
                mood,
                encrypted.get("ciphertext"),
                encrypted.get("iv"),
                encrypted.get("key_version", 1),
                data.get("image_path"),
                datetime.now().isoformat(),
                journal_id,
                user_id,
            ),
        )
    else:
        c.execute(
            "UPDATE journals SET text=?, mood=?, image_path=?, date=? WHERE id=? AND user_id=?",
            (text, mood, data.get("image_path"), datetime.now().isoformat(), journal_id, user_id),
        )
    conn.commit()
    conn.close()
    return jsonify({"success": True})

@app.route("/journals/<int:user_id>/<int:journal_id>/permanent", methods=["DELETE"])
def delete_journal_forever(user_id, journal_id):
    conn = get_db_connection()
    c = conn.cursor()
    c.execute("DELETE FROM journals WHERE id=? AND user_id=? AND is_deleted=1", (journal_id, user_id))
    conn.commit()
    conn.close()
    return jsonify({"success": True})

@app.route("/journals/<int:user_id>/date/<date>", methods=["GET"])
def get_journals_by_date(user_id, date):
    conn = get_db_connection()
    c = conn.cursor()
    c.execute(
        "SELECT * FROM journals WHERE user_id=? AND is_deleted=0 AND date LIKE ? ORDER BY date DESC",
        (user_id, f"{date}%"),
    )
    journals = [dict(row) for row in c.fetchall()]
    conn.close()
    return jsonify(journals)

@app.route("/exports/<int:user_id>/clinical.json", methods=["GET"])
def export_clinical_json(user_id):
    conn = get_db_connection()
    c = conn.cursor()
    c.execute(
        """
        SELECT id, mood, date, confidence, emotion_scores, trigger_categories,
               sentiment_shifts, crisis_flag, is_deleted
        FROM journals
        WHERE user_id=? AND is_deleted=0
        ORDER BY date DESC
        """,
        (user_id,),
    )
    entries = [dict(row) for row in c.fetchall()]
    conn.close()
    payload = {
        "generated_at": datetime.now().isoformat(),
        "user_id": user_id,
        "privacy_note": "Journal body text is excluded from backend clinical export. Encrypted entries remain zero-knowledge.",
        "entries": entries,
    }
    return Response(
        json.dumps(payload, indent=2),
        mimetype="application/json",
        headers={"Content-Disposition": f"attachment; filename=nuromood_clinical_user_{user_id}.json"},
    )

# -------------------- Analyze Text Route --------------------
@app.route("/analyze_text", methods=["POST"])
def analyze_text():
    data = request.json
    text = anonymize_for_model(data.get("text", ""))
    pred, confidence, result = analyze_emotion(text)
    triggers = extract_triggers(text)
    sentiment_shift = detect_sentiment_shift(text)
    crisis_flag, crisis_signal = detect_crisis(text, pred, confidence)
    return jsonify({
        "prediction": pred,
        "primary_emotion": pred,
        "confidence": confidence,
        "confidence_percent": round(confidence * 100, 2),
        "scores": result,
        "top_emotions": top_emotions(result),
        "triggers": triggers,
        "sentiment_shift": sentiment_shift,
        "coping_plan": coping_plan(pred),
        "crisis_flag": crisis_flag,
        "crisis_signal": crisis_signal,
    })

@app.route("/analyze-journal", methods=["POST"])
def analyze_journal():
    data = request.json
    user_id = data.get("user_id")
    encrypted = data.get("encrypted_journal") or {}
    model_text = anonymize_for_model(data.get("model_text", ""))
    if not user_id or not encrypted.get("ciphertext") or not model_text:
        return jsonify({"success": False, "message": "Missing secure journal payload"}), 400

    pred, confidence, scores = analyze_emotion(model_text)
    triggers = extract_triggers(model_text)
    sentiment_shift = detect_sentiment_shift(model_text)
    crisis_flag, crisis_signal = detect_crisis(model_text, pred, confidence)
    date = datetime.now().isoformat()

    conn = get_db_connection()
    c = conn.cursor()
    c.execute(
        """
        INSERT INTO journals (
            user_id, text, mood, date, encrypted_text, encryption_iv,
            encryption_key_version, confidence, emotion_scores, trigger_categories,
            sentiment_shifts, image_path, crisis_flag
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            user_id,
            "[encrypted]",
            pred,
            date,
            encrypted.get("ciphertext"),
            encrypted.get("iv"),
            encrypted.get("key_version", 1),
            confidence,
            json.dumps(scores),
            json.dumps(triggers),
            json.dumps(sentiment_shift),
            data.get("image_path"),
            1 if crisis_flag else 0,
        ),
    )
    journal_id = c.lastrowid
    streak = update_user_streak(c, user_id)
    badges = unlock_badges(c, user_id, streak)
    if crisis_flag:
        c.execute(
            "INSERT INTO crisis_events (user_id, journal_id, signal, confidence) VALUES (?, ?, ?, ?)",
            (user_id, journal_id, crisis_signal or "unknown", confidence),
        )
    conn.commit()
    conn.close()

    return jsonify({
        "journal_id": journal_id,
        "primary_emotion": pred,
        "confidence": confidence,
        "confidence_percent": round(confidence * 100, 2),
        "scores": scores,
        "top_emotions": top_emotions(scores),
        "triggers": triggers,
        "sentiment_shift": sentiment_shift,
        "streak": streak,
        "badges": badges,
        "coping_plan": coping_plan(pred),
        "crisis_flag": crisis_flag,
        "crisis_signal": crisis_signal,
    })

@app.route("/gamification/<int:user_id>", methods=["GET"])
def get_gamification(user_id):
    conn = get_db_connection()
    c = conn.cursor()
    c.execute("SELECT current_streak, longest_streak, last_journal_date FROM user_streaks WHERE user_id=?", (user_id,))
    streak_row = c.fetchone()
    streak = dict(streak_row) if streak_row else {"current_streak": 0, "longest_streak": 0, "last_journal_date": None}
    c.execute("SELECT badge_id, unlocked_at FROM user_badges WHERE user_id=? ORDER BY unlocked_at DESC", (user_id,))
    badges = [dict(row) for row in c.fetchall()]
    conn.close()
    return jsonify({"streak": streak, "badges": badges})

@app.route("/crisis-events", methods=["POST"])
def log_crisis_event():
    data = request.json or {}
    conn = get_db_connection()
    c = conn.cursor()
    c.execute(
        """
        INSERT INTO crisis_events (user_id, journal_id, signal, confidence, user_action)
        VALUES (?, ?, ?, ?, ?)
        """,
        (
            data.get("user_id", 0),
            data.get("journal_id"),
            data.get("signal", "ui_interaction"),
            float(data.get("confidence", 0) or 0),
            data.get("user_action", "shown"),
        ),
    )
    conn.commit()
    conn.close()
    return jsonify({"success": True})


# -------------------- Main --------------------
if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000, debug=True)
