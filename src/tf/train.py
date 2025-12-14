"""Simple TF training example that saves a SavedModel and exports a TFLite file.

This is intentionally minimal and uses random data. Replace the data generation
with your real dataset and preprocessing pipeline.
"""
import os
import numpy as np
import tensorflow as tf


def make_model(input_shape=(10,)):
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=input_shape),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.Dense(1, activation='sigmoid'),
    ])
    model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
    return model


def main():
    out_dir = os.path.join(os.getcwd(), 'models')
    os.makedirs(out_dir, exist_ok=True)

    # Synthetic dataset: replace with real data loader
    x_train = np.random.randn(1024, 10).astype(np.float32)
    y_train = (np.sum(x_train, axis=1) > 0).astype(np.float32)

    model = make_model((10,))
    model.summary()

    model.fit(x_train, y_train, epochs=3, batch_size=32)

    # Save in Keras native format ('.keras') — then load and convert from Keras model
    keras_path = os.path.join(out_dir, 'model.keras')
    model.save(keras_path, include_optimizer=False)
    print(f"Keras model written to: {keras_path}")

    # Load the Keras model and convert to TFLite
    loaded = tf.keras.models.load_model(keras_path)
    converter = tf.lite.TFLiteConverter.from_keras_model(loaded)
    tflite_model = converter.convert()

    tflite_path = os.path.join(out_dir, 'model.tflite')
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    print(f"TFLite model written to: {tflite_path}")


if __name__ == '__main__':
    main()
