MLops training scaffold

Usage:
- Create conda env: `conda env create -f conda.yaml` (or use requirements)
- Add dataset files (fusion_X.npy, fusion_Y.npy)
- Run training locally: `python train.py --config-name=config`
- Or build Docker (GPU host): `docker-compose up --build`
