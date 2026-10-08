from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

Category = Literal["DEVOPS", "CLOUD", "PROGRAMMING", "SYSTEMS", "GENERAL"]


class BookCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    author: str = Field(min_length=1, max_length=120)
    category: Category = "GENERAL"
    total_copies: int = Field(default=1, ge=1, le=100)


class BookUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    author: str | None = Field(default=None, min_length=1, max_length=120)
    category: Category | None = None
    total_copies: int | None = Field(default=None, ge=1, le=100)


class BookOut(BaseModel):
    id: int
    title: str
    author: str
    category: str
    total_copies: int
    available_copies: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class StatsOut(BaseModel):
    titles: int
    total_copies: int
    available_copies: int
    issued_copies: int
