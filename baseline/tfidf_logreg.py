import pandas as pd
import json
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, f1_score, classification_report
import joblib
import os

# === Load dataset ===
train_df = pd.read_csv("../data/train.csv", encoding="utf-8")
val_df   = pd.read_csv("../data/val.csv", encoding="utf-8")

# Change column names if different in your dataset
TEXT_COL = "text"
LABEL_COL = "label"

# === TF-IDF Vectorization ===
vectorizer = TfidfVectorizer(max_features=5000, ngram_range=(1,2))
X_train = vectorizer.fit_transform(train_df[TEXT_COL])
X_val   = vectorizer.transform(val_df[TEXT_COL])

# === Logistic Regression ===
clf = LogisticRegression(max_iter=200)
clf.fit(X_train, train_df[LABEL_COL])

# === Predictions ===
y_pred = clf.predict(X_val)

# === Metrics ===
acc = accuracy_score(val_df[LABEL_COL], y_pred)
f1  = f1_score(val_df[LABEL_COL], y_pred, average="weighted")

print("\nClassification Report:\n")
print(classification_report(val_df[LABEL_COL], y_pred))

# Save results
results = {"Accuracy": acc, "F1_score": f1}
print("Results:", results)

os.makedirs("results", exist_ok=True)
with open("results/tfidf_logreg.json", "w") as f:
    json.dump(results, f, indent=4)

# Save model + vectorizer
joblib.dump(clf, "results/logreg_model.pkl")
joblib.dump(vectorizer, "results/tfidf_vectorizer.pkl")
