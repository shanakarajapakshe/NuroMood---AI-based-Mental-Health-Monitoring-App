import argparse, os, json, torch
import pandas as pd
from torch.utils.data import Dataset, DataLoader
from transformers import AutoTokenizer, AutoModelForSequenceClassification, get_linear_schedule_with_warmup
from torch.optim import AdamW
from tqdm import tqdm
from utils import build_label_map, df_to_features, is_single_label

class TextDataset(Dataset):
    def __init__(self, texts, labels, tokenizer, max_len):
        self.texts, self.labels, self.tokenizer, self.max_len = texts, labels, tokenizer, max_len
    def __len__(self): return len(self.texts)
    def __getitem__(self, idx):
        enc = self.tokenizer(self.texts[idx], truncation=True, padding='max_length',
                             max_length=self.max_len, return_tensors='pt')
        item = {k: v.squeeze(0) for k,v in enc.items()}
        item['labels'] = torch.tensor(self.labels[idx], dtype=torch.float)
        return item

def main(args):
    with open(args.config,"r") as f: cfg = json.load(f)

    train_df = pd.read_csv(cfg["data"]["train_csv"])
    val_df   = pd.read_csv(cfg["data"]["val_csv"])

    label_map = build_label_map(cfg["data"]["label_names"])
    texts_tr, Y_tr = df_to_features(train_df, cfg["data"]["text_col"], label_map, cfg["data"]["labels_col"])
    texts_va, Y_va = df_to_features(val_df, cfg["data"]["text_col"], label_map, cfg["data"]["labels_col"])

    tokenizer = AutoTokenizer.from_pretrained(cfg["model"]["pretrained_name"])
    model = AutoModelForSequenceClassification.from_pretrained(
        cfg["model"]["pretrained_name"],
        num_labels=len(label_map),
        problem_type="single_label_classification"
    )

    train_ds = TextDataset(texts_tr, Y_tr, tokenizer, cfg["model"]["max_length"])
    val_ds   = TextDataset(texts_va, Y_va, tokenizer, cfg["model"]["max_length"])

    train_loader = DataLoader(train_ds, batch_size=cfg["train"]["batch_size"], shuffle=True)
    val_loader   = DataLoader(val_ds, batch_size=cfg["train"]["batch_size"])

    optimizer = AdamW(model.parameters(), lr=cfg["train"]["lr"], weight_decay=cfg["train"]["weight_decay"])
    scheduler = get_linear_schedule_with_warmup(optimizer, 0, len(train_loader)*cfg["train"]["num_epochs"])
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.to(device)

    for epoch in range(cfg["train"]["num_epochs"]):
        model.train()
        for batch in tqdm(train_loader, desc=f"Epoch {epoch+1}"):
            batch = {k: v.to(device) for k, v in batch.items()}
            batch["labels"] = batch["labels"].long()

            loss = model(**batch).loss
            loss.backward(); optimizer.step(); scheduler.step(); optimizer.zero_grad()
        print(f"Epoch {epoch+1} finished")

    model.save_pretrained("artifacts/nuromood_model")
    tokenizer.save_pretrained("artifacts/nuromood_model")

    model.save_pretrained(cfg["output_dir"])
    tokenizer.save_pretrained(cfg["output_dir"])
    with open(os.path.join(cfg["output_dir"], "label_names.json"), "w") as f:
        json.dump(cfg["data"]["label_names"], f)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=str, default="config.json")
    args = parser.parse_args()
    main(args)

