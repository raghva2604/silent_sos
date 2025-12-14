#!/usr/bin/env python3
"""Convert SavedModel to a quantized TFLite (INT8) model.

Usage:
  python convert_to_tflite.py

Make sure `severity_saved_model/` exists (created by train_severity.py).
"""
import os
import numpy as np
import tensorflow as tf


def representative_data_gen():
    # Simple generator using a few example strings. Replace with representative samples from your corpus.
    samples = [
        "person bleeding heavily",
        "i think they fainted",
        "minor cut on finger",
        "unconscious and not breathing",
        "small bruise and stable",
    ]
    for s in samples:
        # TFLite string-representative dataset may require bytes objects
        yield [np.array([s], dtype=object)]


def main():
    saved = 'severity_saved_model'
    if not os.path.exists(saved):
        print(f"Saved model not found at {saved}. Run train_severity.py first.")
        return

    converter = tf.lite.TFLiteConverter.from_saved_model(saved)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    try:
        converter.representative_dataset = representative_data_gen
    except Exception as e:
        print('Warning: could not set representative dataset:', e)

    # Try to target INT8; if unsupported, fallback to default float32 TFLite
    try:
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        converter.inference_input_type = tf.uint8
        converter.inference_output_type = tf.uint8
    except Exception:
        print('INT8 conversion not available in this environment. Producing float32 TFLite.')

    tflite_model = converter.convert()
    out_path = 'severity_model.tflite'
    with open(out_path, 'wb') as f:
        f.write(tflite_model)
    print(f'Saved TFLite model to {out_path}')


if __name__ == '__main__':
    main()
