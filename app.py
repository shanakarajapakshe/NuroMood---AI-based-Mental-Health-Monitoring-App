from flask import Flask, request, jsonify
from flask_cors import CORS
import sqlite3
from datetime import datetime
import torch, json
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
    conn.commit()
    conn.close()

def get_db_connection():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn

# -------------------- User Routes --------------------
@app.route("/register", methods=["POST"])
def register():
    data = request.json
    email = data.get("email")
    password = data.get("password")
    conn = get_db_connection()
    c = conn.cursor()
    try:
        c.execute("INSERT INTO users (email, password) VALUES (?, ?)", (email, password))
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
    c.execute("SELECT * FROM users WHERE email=? AND password=?", (email, password))
    user = c.fetchone()
    conn.close()
    if user:
        return jsonify({"success": True, "user_id": user["id"]})
    return jsonify({"success": False, "message": "Invalid email or password"}), 401

# -------------------- Journal Routes --------------------
@app.route("/journals/<int:user_id>", methods=["GET"])
def get_journals(user_id):
    conn = get_db_connection()
    c = conn.cursor()
    c.execute("SELECT * FROM journals WHERE user_id=? AND is_deleted=0 ORDER BY date DESC", (user_id,))
    journals = [dict(row) for row in c.fetchall()]
    conn.close()
    return jsonify(journals)

@app.route("/journals/<int:user_id>/trash", methods=["GET"])
def get_trash(user_id):
    conn = get_db_connection()
    c = conn.cursor()
    c.execute("SELECT * FROM journals WHERE user_id=? AND is_deleted=1 ORDER BY date DESC", (user_id,))
    trash = [dict(row) for row in c.fetchall()]
    conn.close()
    return jsonify(trash)

@app.route("/journals/<int:user_id>", methods=["POST"])
def add_journal(user_id):
    data = request.json
    text = data.get("text")
    mood = data.get("mood")
    date = datetime.now().isoformat()
    conn = get_db_connection()
    c = conn.cursor()
    c.execute(
        "INSERT INTO journals (user_id, text, mood, date) VALUES (?, ?, ?, ?)",
        (user_id, text, mood, date)
    )
    conn.commit()
    conn.close()
    return jsonify({"success": True})

@app.route("/journals/<int:user_id>/<int:journal_id>", methods=["DELETE"])
def move_to_trash(user_id, journal_id):
    conn = get_db_connection()
    c = conn.cursor()
    c.execute("UPDATE journals SET is_deleted=1 WHERE id=? AND user_id=?", (journal_id, user_id))
    conn.commit()
    conn.close()
    return jsonify({"success": True})

@app.route("/journals/<int:user_id>/<int:journal_id>/restore", methods=["POST"])
def restore_journal(user_id, journal_id):
    conn = get_db_connection()
    c = conn.cursor()
    c.execute("UPDATE journals SET is_deleted=0 WHERE id=? AND user_id=?", (journal_id, user_id))
    conn.commit()
    conn.close()
    return jsonify({"success": True})

# -------------------- Analyze Text Route --------------------
@app.route("/analyze_text", methods=["POST"])
def analyze_text():
    data = request.json
    text = data.get("text", "")
    enc = tok([text], truncation=True, padding=True, max_length=160, return_tensors='pt')
    with torch.no_grad():
        logits = model(**enc).logits
    probs = torch.softmax(logits, dim=1).numpy()[0]
    result = {LABELS[i]: float(p) for i, p in enumerate(probs)}
    pred = LABELS[probs.argmax()]
    return jsonify({"prediction": pred, "scores": result})


# -------------------- Main --------------------
if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000, debug=True)
