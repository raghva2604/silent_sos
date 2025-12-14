#!/usr/bin/env python3
import argparse
import os
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--images", action="store_true")
parser.add_argument("--falls", action="store_true")
parser.add_argument("--augment", action="store_true")
parser.add_argument("--validate", action="store_true")
parser.add_argument("--split", action="store_true")
parser.add_argument("--train-image", action="store_true")
parser.add_argument("--train-fall", action="store_true")
args = parser.parse_args()

if args.images:
    subprocess.run(["python", "..\tools\generate_image_dataset.py"], cwd=os.path.dirname(__file__))

if args.augment:
    subprocess.run(["python", "..\tools\augment_images.py"], cwd=os.path.dirname(__file__))

if args.validate:
    subprocess.run(["python", "..\tools\validate_images.py"], cwd=os.path.dirname(__file__))

if args.split:
    subprocess.run(["python", "..\tools\split_dataset.py"], cwd=os.path.dirname(__file__))

if args.falls:
    subprocess.run(["python", "..\tools\generate_fall_sensor_data.py"], cwd=os.path.dirname(__file__))

if args.train_image:
    subprocess.run(["python", "..\training\train_image_model.py"], cwd=os.path.dirname(__file__))

if args.train_fall:
    subprocess.run(["python", "..\training\train_fall_model.py"], cwd=os.path.dirname(__file__))
