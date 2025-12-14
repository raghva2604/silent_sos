import argparse
import numpy as np
from torch.utils.data import Dataset, DataLoader

class FusionDataset(Dataset):
    def __init__(self, X_path='fusion_X.npy', Y_path='fusion_Y.npy'):
        self.X = np.load(X_path)
        self.Y = np.load(Y_path)

    def __len__(self):
        return len(self.X)

    def __getitem__(self, idx):
        return self.X[idx].astype('float32'), self.Y[idx].astype('float32')

class FusionDataModule:
    def __init__(self, cfg):
        self.cfg = cfg

    def setup(self, stage=None):
        self.train = FusionDataset('fusion_X.npy', 'fusion_Y.npy')

    def train_dataloader(self):
        return DataLoader(self.train, batch_size=self.cfg.data.batch_size, shuffle=True)
