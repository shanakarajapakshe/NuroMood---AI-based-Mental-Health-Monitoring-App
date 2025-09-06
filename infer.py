import argparse, json, torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification

def predict(text, artifacts="artifacts"):
    with open(f"{artifacts}/label_names.json","r") as f: labels = json.load(f)
    tok = AutoTokenizer.from_pretrained(artifacts)
    model = AutoModelForSequenceClassification.from_pretrained(artifacts)
    enc = tok([text], truncation=True, padding=True, max_length=160, return_tensors='pt')
    with torch.no_grad(): logits = model(**enc).logits
    probs = torch.softmax(logits, dim=1).numpy()[0]
    pred = labels[probs.argmax()]
    return pred, {labels[i]: float(p) for i,p in enumerate(probs)}

if __name__=="__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--text", type=str, default="today is so bad day ")
    args = parser.parse_args()
    pred, res = predict(args.text)
    print("Prediction:", pred)
    print("Scores:", res)
