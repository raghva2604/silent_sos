import os, shutil, random

SOURCE = "dataset_augmented"
TARGET = "dataset_split"

for label in os.listdir(SOURCE):
    files = os.listdir(os.path.join(SOURCE, label))
    random.shuffle(files)

    n = len(files)
    train = files[:int(n*0.7)]
    val = files[int(n*0.7):int(n*0.85)]
    test = files[int(n*0.85):]

    for split_name, split_files in zip(["train", "val", "test"], [train, val, test]):
        split_dir = f"{TARGET}/{split_name}/{label}"
        os.makedirs(split_dir, exist_ok=True)
        for f in split_files:
            shutil.copy(os.path.join(SOURCE, label, f), split_dir)
