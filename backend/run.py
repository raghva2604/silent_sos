#!/usr/bin/env python
"""Simple launcher for uvicorn to avoid module loading issues."""

import uvicorn
import sys
import os

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    uvicorn.run("server:app", host="0.0.0.0", port=8000, workers=1, reload=False)
