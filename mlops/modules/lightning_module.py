import pytorch_lightning as pl
import torch
import torch.nn as nn
import torch.optim as optim

class FusionModule(pl.LightningModule):
    def __init__(self, cfg):
        super().__init__()
        self.save_hyperparameters(cfg)
        self.net = nn.Sequential(
            nn.Linear(3, 32),
            nn.ReLU(),
            nn.Linear(32, 16),
            nn.ReLU(),
            nn.Linear(16, 1),
            nn.Sigmoid()
        )
        self.criterion = nn.BCELoss()

    def forward(self, x):
        return self.net(x).squeeze(-1)

    def training_step(self, batch, batch_idx):
        x, y = batch
        y_hat = self(x)
        loss = self.criterion(y_hat, y.float())
        self.log('train_loss', loss)
        return loss

    def validation_step(self, batch, batch_idx):
        x, y = batch
        y_hat = self(x)
        loss = self.criterion(y_hat, y.float())
        self.log('val_loss', loss, prog_bar=True)
        return {"val_loss": loss}

    def configure_optimizers(self):
        return optim.Adam(self.parameters(), lr=self.hparams.model.lr)
