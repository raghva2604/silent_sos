import sys

try:
    import numpy as np  # type: ignore[import]
    import tensorflow as tf  # type: ignore[import]
    import pandas as pd  # type: ignore[import]
    from tensorflow.keras import layers, models  # type: ignore[import]
except ImportError as e:
    print(f'❌ Missing dependencies: {e}')
    print('   Install with: pip install numpy tensorflow pandas')
    sys.exit(1)

import os

SEQ_LEN = 128  # 2.56 seconds at 50Hz
DATA_DIR = "fall_dataset"

def load_sequence(path):
    df = pd.read_csv(path)
    x = df['x'].values[:SEQ_LEN]
    y = df['y'].values[:SEQ_LEN]
    z = df['z'].values[:SEQ_LEN]
    mag = np.sqrt(x*x + y*y + z*z)
    
    if len(mag) < SEQ_LEN:
        mag = np.pad(mag, (0, SEQ_LEN - len(mag)))
    
    return mag

X = []
Y = []

label_map = {"non_fall": 0, "fall": 1}

for label in ["non_fall", "fall"]:
    folder = os.path.join(DATA_DIR, label)
    if not os.path.isdir(folder):
        print(f"Warning: {folder} not found; skipping")
        continue
    for file in os.listdir(folder):
        if file.endswith(".csv"):
            path = os.path.join(folder, file)
            seq = load_sequence(path)
            X.append(seq)
            Y.append(label_map[label])

X = np.array(X)
Y = np.array(Y)

# reshape for CNN input
X = X.reshape((-1, SEQ_LEN, 1))

print("Loaded sequences:", X.shape)

# 1D CNN MODEL
model = models.Sequential([
    layers.Conv1D(32, 5, activation='relu', input_shape=(SEQ_LEN, 1)),
    layers.MaxPooling1D(2),
    layers.Conv1D(64, 5, activation='relu'),
    layers.MaxPooling1D(2),
    layers.Conv1D(128, 5, activation='relu'),
    layers.GlobalAveragePooling1D(),
    layers.Dense(64, activation='relu'),
    layers.Dense(1, activation='sigmoid')  # fall vs no-fall
])

model.compile(
    optimizer='adam',
    loss='binary_crossentropy',
    metrics=['accuracy']
)

history = model.fit(
    X, Y,
    epochs=20,
    batch_size=32,
    validation_split=0.2,
    shuffle=True
)

os.makedirs("training/output", exist_ok=True)
model.save("training/output/fall_detector_model.h5")
print("Saved training/output/fall_detector_model.h5")

# Convert to TFLite (quantized)
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

with open("training/output/fall_detector_model.tflite", "wb") as f:
    f.write(tflite_model)

print("Saved training/output/fall_detector_model.tflite")
