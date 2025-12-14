#!/usr/bin/env python3
"""Train a small severity classifier and save a SavedModel.

Usage:
  python train_severity.py

This script expects a CSV at `severity_dataset.csv` in the same folder with columns
`text,label`. Labels will be inferred automatically.
"""
import os
import json
import pandas as pd
import tensorflow as tf
from tensorflow.keras import layers, Model


def main():
    csv_path = 'severity_dataset.csv'
    if not os.path.exists(csv_path):
        print(f"Dataset not found: {csv_path}. Create CSV with columns text,label and retry.")
        return

    df = pd.read_csv(csv_path)
    texts = df['text'].astype(str).tolist()
    labels_raw = df['label'].astype('category')
    labels = labels_raw.cat.codes.values
    label_map = dict(enumerate(labels_raw.cat.categories))
    print("Label map:", label_map)

    max_tokens = 8000
    seq_len = 64
    vec = layers.TextVectorization(max_tokens=max_tokens, output_sequence_length=seq_len)
    vec.adapt(texts)

    inp = layers.Input(shape=(1,), dtype=tf.string, name='text_input')
    x = vec(inp)
    x = layers.Embedding(max_tokens, 64)(x)
    x = layers.Conv1D(64, 3, activation='relu')(x)
    x = layers.GlobalAveragePooling1D()(x)
    x = layers.Dense(64, activation='relu')(x)
    out = layers.Dense(len(label_map), activation='softmax')(x)
    model = Model(inputs=inp, outputs=out)
    model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])
    model.summary()

    model.fit(x=texts, y=labels, epochs=8, batch_size=32, validation_split=0.12)

    saved = 'severity_saved_model'
    print(f"Saving model to {saved}")
    model.save(saved)

    # persist label map and vectorizer vocabulary for later use or inspection
    meta = {'label_map': label_map}
    with open('severity_label_map.json', 'w') as f:
        json.dump(meta, f)

    print('Training complete. Run convert_to_tflite.py to create a quantized TFLite model.')


if __name__ == '__main__':
    main()
