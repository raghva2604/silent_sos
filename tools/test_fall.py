#!/usr/bin/env python3
import argparse
import numpy as np
import tensorflow as tf
import pandas as pd


def load_seq_csv(path, seq_len=128):
    df = pd.read_csv(path)
    if 'x' in df.columns and 'y' in df.columns and 'z' in df.columns:
        mag = (df['x']**2 + df['y']**2 + df['z']**2)**0.5
        arr = mag.values
    else:
        arr = df.values.flatten()
    if len(arr) < seq_len:
        arr = np.pad(arr, (0, seq_len-len(arr)))
    return arr.reshape(1, seq_len, 1).astype('float32')


def run_tflite(model_path, csv_path):
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    inp = load_seq_csv(csv_path, seq_len=input_details[0]['shape'][1])

    # Adjust dtype if necessary
    if input_details[0]['dtype'] == np.uint8:
        # scale to uint8 range if needed (assumes model expects 0-255)
        inp = (inp * 255).astype(np.uint8)

    interpreter.set_tensor(input_details[0]['index'], inp)
    interpreter.invoke()
    out = interpreter.get_tensor(output_details[0]['index'])
    print("Output:", out)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--model", required=True)
    p.add_argument("--csv", required=True)
    args = p.parse_args()
    run_tflite(args.model, args.csv)
