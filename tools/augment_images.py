import os
from PIL import Image, ImageEnhance
import random

INPUT_DIR = "dataset"
OUTPUT_DIR = "dataset_augmented"
os.makedirs(OUTPUT_DIR, exist_ok=True)


def augment(img):
    # random brightness
    if random.random() < 0.5:
        enhancer = ImageEnhance.Brightness(img)
        img = enhancer.enhance(random.uniform(0.6, 1.4))

    # random contrast
    if random.random() < 0.5:
        enhancer = ImageEnhance.Contrast(img)
        img = enhancer.enhance(random.uniform(0.6, 1.4))

    # random flips
    if random.random() < 0.5:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)

    # random rotations
    img = img.rotate(random.uniform(-20, 20))

    return img

for label in os.listdir(INPUT_DIR):
    class_dir = os.path.join(INPUT_DIR, label)
    out_dir = os.path.join(OUTPUT_DIR, label)
    os.makedirs(out_dir, exist_ok=True)

    for file in os.listdir(class_dir):
        image_path = os.path.join(class_dir, file)
        try:
            img = Image.open(image_path)
        except Exception as e:
            print(f"Skipping {image_path}: {e}")
            continue

        augmented = augment(img)
        out_path = os.path.join(out_dir, "aug_" + file)
        augmented.save(out_path)
        print("Saved augmented:", out_path)
