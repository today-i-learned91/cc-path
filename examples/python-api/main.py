"""
Minimal FastAPI example for cc-path harness demonstration.
Three endpoints: health check, list items, create item.
"""

import os
from typing import Optional
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel

load_dotenv()

API_KEY = os.getenv("API_KEY")
if not API_KEY:
    raise RuntimeError("API_KEY is not set. Copy .env.example to .env and fill in values.")

app = FastAPI(title="cc-path Python API Example", version="0.1.0")

# In-memory store — not for production use
_items: dict[int, dict] = {}
_next_id: int = 1


class Item(BaseModel):
    name: str
    description: Optional[str] = None


class ItemResponse(BaseModel):
    id: int
    name: str
    description: Optional[str] = None


def _verify_key(x_api_key: Optional[str]) -> None:
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")


@app.get("/health")
def health() -> dict:
    """Health check — no auth required."""
    return {"status": "ok"}


@app.get("/items", response_model=list[ItemResponse])
def list_items(x_api_key: Optional[str] = Header(default=None)) -> list[ItemResponse]:
    """Return all items."""
    _verify_key(x_api_key)
    return [ItemResponse(id=k, **v) for k, v in _items.items()]


@app.post("/items", response_model=ItemResponse, status_code=201)
def create_item(
    item: Item,
    x_api_key: Optional[str] = Header(default=None),
) -> ItemResponse:
    """Create a new item."""
    _verify_key(x_api_key)
    global _next_id
    item_id = _next_id
    _next_id += 1
    _items[item_id] = {"name": item.name, "description": item.description}
    return ItemResponse(id=item_id, **_items[item_id])
