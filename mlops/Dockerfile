FROM python:3.10-slim

WORKDIR /workspace
COPY . /workspace
RUN pip install --upgrade pip && pip install -r requirements.txt || true
CMD ["python", "train.py", "hydra.run.dir=."]
