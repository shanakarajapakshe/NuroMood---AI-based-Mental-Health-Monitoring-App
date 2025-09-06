import numpy as np
import pandas as pd

def build_label_map(label_names):
    return {name: idx for idx, name in enumerate(label_names)}

def encode_single_label(label, label_map):
    vec = np.zeros(len(label_map), dtype=np.float32)
    if label in label_map:
        vec[label_map[label]] = 1.0
    return vec

def df_to_features(df, text_col, label_map, labels_col):
    texts = df[text_col].astype(str).tolist()
    # map each label string directly to its integer index
    Y = df[labels_col].map(label_map).values
    return texts, Y


def is_single_label(Y):
    return np.all((Y.sum(axis=1) >= 0.99) & (Y.sum(axis=1) <= 1.01))
