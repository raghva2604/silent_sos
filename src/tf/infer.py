"""Example that runs inference with the exported TFLite model.

Requires the same `tensorflow` installation (full TF includes the TFLite Interpreter).
"""
import os
import numpy as np
import tensorflow as tf


def run_tflite(tflite_path):
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    # Build a dummy input matching the expected shape
    shape = input_details[0]['shape']
    sample = np.random.randn(*shape).astype(np.float32)

    interpreter.set_tensor(input_details[0]['index'], sample)
    interpreter.invoke()
    out = interpreter.get_tensor(output_details[0]['index'])
    return out


def main():
    tflite_path = os.path.join(os.getcwd(), 'models', 'model.tflite')
    if not os.path.exists(tflite_path):
        print('TFLite model not found. Run `python src/tf/train.py` first.')
        return

    out = run_tflite(tflite_path)
    print('Inference output (sample):', out)


if __name__ == '__main__':
    main()
