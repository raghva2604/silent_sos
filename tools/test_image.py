#!/usr/bin/env python3
import argparse
import numpy as np
import tensorflow as tf
from PIL import Image

LABELS = ["normal","fight","blood","weapon","injury","fall"]  # update if different


def load_image(path, size=(224,224)):
    img = Image.open(path).convert("RGB").resize(size)
    arr = np.array(img).astype('float32') / 255.0
    return np.expand_dims(arr, 0)


def run_tflite(model_path, image_path):
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    # Determine expected input size
    in_shape = input_details[0]['shape']
    # if shape is [1, H, W, C]
    if len(in_shape) >= 4:
        height = int(in_shape[1])
        width = int(in_shape[2])
    else:
        height, width = 224, 224

    img = load_image(image_path, size=(width, height))
    # Adjust dtype if necessary
    if input_details[0]['dtype'] == np.uint8:
        img = (img * 255).astype(np.uint8)

    interpreter.set_tensor(input_details[0]['index'], img)
    interpreter.invoke()
    out = interpreter.get_tensor(output_details[0]['index'])
    probs = out[0]
    idx = int(np.argmax(probs))
    print("Predicted:", LABELS[idx], "score:", float(probs[idx]))
    for i,p in enumerate(probs):
        label = LABELS[i] if i < len(LABELS) else f"class_{i}"
        print(f"{label}: {p:.4f}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--model", required=True)
    p.add_argument("--image", required=True)
    args = p.parse_args()
    run_tflite(args.model, args.image)
