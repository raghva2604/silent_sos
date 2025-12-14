import os
from PIL import Image

DATASET = "dataset"

for label in os.listdir(DATASET):
    path = os.path.join(DATASET, label)
    for file in os.listdir(path):
        file_path = os.path.join(path, file)
        try:
            img = Image.open(file_path)
            img.verify()
        except Exception:
            print("Bad file removed:", file_path)
            try:
                os.remove(file_path)
            except Exception:
                pass
