import numpy as np
import pandas as pd
import os
import random

OUTPUT = "fall_dataset"
os.makedirs(f"{OUTPUT}/fall", exist_ok=True)
os.makedirs(f"{OUTPUT}/non_fall", exist_ok=True)

SEQ_LEN = 128  # 2.56 seconds at 50Hz


def generate_normal_motion():
    x = np.random.normal(0, 0.2, SEQ_LEN)
    y = np.random.normal(0, 0.2, SEQ_LEN)
    z = np.random.normal(9.8, 0.3, SEQ_LEN)  # gravity
    return np.vstack([x, y, z]).T


def generate_fall_motion():
    x = np.random.normal(0, 0.3, SEQ_LEN)
    y = np.random.normal(0, 0.3, SEQ_LEN)
    z = np.random.normal(9.8, 0.5, SEQ_LEN)

    # add impact spike
    impact_index = random.randint(40, 80)
    z[impact_index:impact_index+4] += np.random.uniform(12, 25)

    # add collapse
    z[impact_index+4:] = np.random.uniform(-1, 3)

    return np.vstack([x, y, z]).T


for i in range(500):
    seq = generate_fall_motion()
    pd.DataFrame(seq, columns=["x", "y", "z"]).to_csv(f"{OUTPUT}/fall/fall_{i}.csv", index=False)

for i in range(500):
    seq = generate_normal_motion()
    pd.DataFrame(seq, columns=["x", "y", "z"]).to_csv(f"{OUTPUT}/non_fall/normal_{i}.csv", index=False)

print("Generated synthetic fall dataset.")
