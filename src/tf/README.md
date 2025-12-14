# TensorFlow integration (Python)

This folder contains minimal example scripts to train a small TensorFlow model, export a SavedModel and a TFLite file, and run inference locally.

Files
- `train.py` — trains a tiny model on random data and exports `models/saved_model/` and `models/model.tflite`.
- `infer.py` — loads the TFLite model using TensorFlow's Interpreter and runs an example inference.
- `requirements-tf.txt` — Python packages required to run the scripts.

Quick start (Python 3.8+)

1. Create a virtual environment and install requirements:

```bash
python -m venv .venv
.\.venv\Scripts\Activate.ps1    # PowerShell (Windows)
pip install -r src/tf/requirements-tf.txt
```

2. Train and export TFLite:

```bash
python src/tf/train.py
```

3. Run a quick inference with the TFLite model:

```bash
python src/tf/infer.py
```

Notes
- These examples use synthetic/random data to keep the scripts small and dependency-free. Replace the data-loading section with your real dataset.
- The training script exports both a SavedModel and a TFLite flatbuffer to `models/`.
