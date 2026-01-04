# NuroMood AI-based-Mental-Health-Monitoring-App 🧠✨  
AI-powered mental health journaling app built with Flutter, Flask, and DistilBERT for emotion detection.

## 📌 Overview
**NeuroMood** is an AI-powered web/mobile application designed to monitor users’ mental well-being by analyzing free-form textual input such as daily journals and reflections. Using advanced **Natural Language Processing (NLP)** and **Transformer-based models (DistilBERT)**, the system classifies emotional states including *joy, sadness, anger, fear, anxiety,* and *neutral*.

The application helps users gain emotional awareness, track mood trends over time, and receive personalized feedback while maintaining strong privacy and security standards.

This project was developed as part of the **BSc (Hons) Software Engineering** degree at **Cardiff Metropolitan University (ICBT Campus)**.


## 🎯 Objectives
- Analyze user-generated text to detect emotional states
- Apply **BERT/DistilBERT** for fine-grained emotion classification
- Provide mood trend visualization and emotional insights
- Ensure data privacy, security, and ethical AI usage
- Deliver a scalable, user-friendly web/mobile solution


## 🛠️ Technology Stack

### Frontend
- **Flutter (Dart)** – Cross-platform UI (Android, iOS, Web, Desktop)
- Material UI Components
- fl_chart – Mood trend visualization
- Local Storage:  
  - SQLite (sqflite / sqflite_common_ffi)  
  - Hive (Web)

### Backend
- **Flask (Python)** – REST API
- flask_cors – Cross-origin support
- SQLite – Backend database

### AI / Machine Learning
- **DistilBERT** (Hugging Face Transformers)
- PyTorch
- Pre-trained & fine-tuned emotion classification models
- Datasets: GoEmotions, DailyDialog (and custom samples)

## ⚙️ System Features

### ✅ Core Features
- User authentication (Register / Login)
- Daily journal entry creation & management
- AI-based emotion detection from text
- Multi-class emotion classification
- Mood history & trend visualization
- Personalized tips & feedback
- Secure data storage with encryption principles

### 🔒 Privacy & Ethics
- User-controlled data
- Secure storage & anonymization
- GDPR / HIPAA-aware design principles
- No forced clinical diagnosis (supportive tool only)


## 🧩 System Architecture
Flutter App (UI)
|
v
Flask REST API
|
v
DistilBERT Emotion Model
|
v
SQLite Database


## 🧠 AI Model Details
- Model: **DistilBERT**
- Approach: Fine-tuned transformer-based text classification
- Emotion Classes:
  - Joy
  - Sadness
  - Anger
  - Fear
  - Anxiety
  - Neutral
- Supports real-time inference suitable for mobile/web deployment

## 🚀 Installation & Setup

### Backend Setup
git clone https://github.com/shanakarajapakshe/neuromood.git
cd backend
pip install -r requirements.txt
python app.py
Frontend Setup
bash
Copy code
cd frontend
flutter pub get
flutter run

## 🧪 Testing
Functional testing for journal management
Emotion classification accuracy validation
UI responsiveness testing
API performance testing

## 📈 Future Enhancements
Multimodal emotion analysis (voice & facial cues)
Cloud deployment with secure APIs
Clinician dashboard integration (with consent)
On-device inference using ONNX
Mood prediction & early warning alerts

## 👨‍🎓 Author
C. Shanaka Lakshitha Rajapakse
BSc (Hons) Software Engineering
ICBT Campus | Cardiff Metropolitan University

## 📄 License
This project is developed for academic purposes.
You may use, modify, and reference it with proper attribution.

## ⚠️ Disclaimer
NeuroMood is not a medical diagnostic tool.
It is intended for emotional awareness and mental well-being support only.
