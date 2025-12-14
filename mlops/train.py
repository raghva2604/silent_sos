import hydra
from omegaconf import DictConfig
import pytorch_lightning as pl
from modules.lightning_module import FusionModule
from modules.data import FusionDataModule
from pytorch_lightning.loggers import WandbLogger

@hydra.main(config_path="configs", config_name="config")
def main(cfg: DictConfig):
    logger = WandbLogger(project=cfg.wandb.project, entity=cfg.wandb.entity, log_model=True)
    pl.seed_everything(cfg.seed)
    dm = FusionDataModule(cfg)
    dm.setup()
    model = FusionModule(cfg)
    trainer = pl.Trainer(max_epochs=cfg.trainer.max_epochs,
                         accelerator='gpu' if cfg.trainer.gpus>0 else 'cpu',
                         devices=1 if cfg.trainer.gpus>0 else None,
                         logger=logger)
    trainer.fit(model, dm.train_dataloader())

if __name__ == "__main__":
    main()
