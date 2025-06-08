#!/usr/bin/env python3
"""
Python FastAPI Application Template for GitLab-Centered DevOps Suite
"""

import os
from typing import List, Dict, Any
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

app = FastAPI(
    title="Python API Template",
    description="A Python FastAPI template for GitLab-Centered DevOps Suite",
    version="1.0.0"
)

class Item(BaseModel):
    """Data model for items"""
    id: int
    name: str
    
@app.get("/")
def read_root() -> Dict[str, Any]:
    """Root endpoint"""
    return {
        "message": "Welcome to your Python FastAPI application",
        "version": "1.0.0",
        "status": "running"
    }

@app.get("/health")
def health_check() -> Dict[str, str]:
    """Health check endpoint for Kubernetes probes"""
    return {"status": "ok"}

@app.get("/api/data", response_model=List[Item])
def get_data() -> List[Dict[str, Any]]:
    """Get sample data"""
    return [
        {"id": 1, "name": "Item 1"},
        {"id": 2, "name": "Item 2"},
        {"id": 3, "name": "Item 3"},
    ]

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=False)
