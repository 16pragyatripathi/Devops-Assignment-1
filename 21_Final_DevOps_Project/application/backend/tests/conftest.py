import os
import tempfile

import pytest

# Tests never touch PostgreSQL: they use a throw-away SQLite file.
_db_file = os.path.join(tempfile.mkdtemp(), "test.db")
os.environ["DATABASE_URL"] = f"sqlite:///{_db_file}"

from fastapi.testclient import TestClient  # noqa: E402

from app.db import Base, engine  # noqa: E402
from app.main import app  # noqa: E402


@pytest.fixture()
def client():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    with TestClient(app) as c:
        yield c


@pytest.fixture()
def book(client):
    r = client.post("/api/books", json={"title": "Site Reliability Engineering", "author": "Betsy Beyer",
                                        "category": "DEVOPS", "total_copies": 2})
    assert r.status_code == 201
    return r.json()
