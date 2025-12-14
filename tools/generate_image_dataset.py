# NOTE: Stable Diffusion generation requires GPU and proper environment.
# This script uses Diffusers; make sure you have torch, diffusers and accelerate installed.

import os
import random
import sys

torch = None
StableDiffusionPipeline = None

try:
    import torch  # type: ignore[import]
    from diffusers import StableDiffusionPipeline  # type: ignore[import]
except ImportError as e:
    print(f"⚠️  Stable Diffusion imports unavailable: {e}")
    print("   To enable image generation, install:")
    print("   pip install torch torchvision diffusers accelerate")
    sys.exit(1)

DEVICE = "cuda" if (torch is not None and torch.cuda.is_available()) else "cpu"

prompts = {
    "fight": [
        "two people fighting violently, action scene, blurred motion, street fight",
        "physical aggression happening, dramatic action scene"
    ],
    "blood": [
        "blood on floor, injury aftermath, realistic",
        "blood stains on ground, medical emergency scene"
    ],
    "weapon": [
        "person holding a knife in a threatening way",
        "gun visible in hand, danger situation"
    ],
    "injury": [
        "person injured, bruises, bleeding, emergency scene",
        "injured victim on ground, needs help"
    ],
    "fall": [
        "person falling down, tripping, collapsing backwards",
        "accidental fall, person on the floor"
    ],
    "normal": [
        "normal street scene, nothing happening",
        "people walking peacefully, safe environment"
    ]
}

OUTPUT_DIR = "image_danger_dataset"
NUM_SAMPLES = 200  # per class

os.makedirs(OUTPUT_DIR, exist_ok=True)
for label in prompts.keys():
    os.makedirs(os.path.join(OUTPUT_DIR, label), exist_ok=True)

# If Diffusers isn't available, this will exit gracefully.
if StableDiffusionPipeline is None:
    print("StableDiffusionPipeline not available - dataset folders created only.")
else:
    pipe = StableDiffusionPipeline.from_pretrained("runwayml/stable-diffusion-v1-5")
    pipe = pipe.to(DEVICE)

    for label, prompt_list in prompts.items():
        save_dir = os.path.join(OUTPUT_DIR, label)
        for i in range(NUM_SAMPLES):
            prompt = random.choice(prompt_list)
            image = pipe(prompt).images[0]
            path = os.path.join(save_dir, f"{label}_{i}.jpg")
            image.save(path)
            print("Generated:", path)
