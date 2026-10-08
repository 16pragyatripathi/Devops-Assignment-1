import logging
import socket
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from prometheus_client import Counter
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from .config import settings
from .db import Base, engine, get_db
from .models import Book
from .schemas import BookCreate, BookOut, BookUpdate, StatsOut

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger("pragya-library")

# Business metric: how many times books were issued / returned
LOANS = Counter("library_loans_total", "Book issue/return operations", ["action"])


@asynccontextmanager
async def lifespan(_: FastAPI):
    # In the container Alembic creates the schema before Uvicorn starts.
    # create_all is a no-op then, and keeps the SQLite test database self-contained.
    Base.metadata.create_all(bind=engine)
    log.info("starting %s version %s", settings.app_name, settings.app_version)
    yield


app = FastAPI(title=settings.app_name, version=settings.app_version, lifespan=lifespan)
Instrumentator(excluded_handlers=["/metrics"]).instrument(app).expose(app, endpoint="/metrics")


def _get_book(db: Session, book_id: int) -> Book:
    book = db.get(Book, book_id)
    if book is None:
        raise HTTPException(status_code=404, detail="Book not found")
    return book


@app.get("/")
def root():
    return {"service": settings.app_name, "version": settings.app_version, "docs": "/docs"}


@app.get("/health")
def health():
    """Liveness: the process is up. Does not touch the database."""
    return {"status": "UP"}


@app.get("/ready")
def ready(db: Session = Depends(get_db)):
    """Readiness: only ready when the database answers."""
    try:
        db.execute(text("SELECT 1"))
    except Exception as exc:  # noqa: BLE001
        log.error("readiness check failed: %s", exc.__class__.__name__)
        raise HTTPException(status_code=503, detail="database not reachable") from exc
    return {"status": "READY"}


@app.get("/api/info")
def info():
    """Which version / which Pod answered - handy to watch rolling updates."""
    return {"service": settings.app_name, "version": settings.app_version, "hostname": socket.gethostname()}


@app.get("/api/books", response_model=list[BookOut])
def list_books(category: str | None = None, db: Session = Depends(get_db)):
    query = select(Book).order_by(Book.id)
    if category:
        query = query.where(Book.category == category.upper())
    return list(db.scalars(query))


@app.get("/api/books/stats", response_model=StatsOut)
def stats(db: Session = Depends(get_db)):
    titles, total, available = db.execute(
        select(
            func.count(Book.id),
            func.coalesce(func.sum(Book.total_copies), 0),
            func.coalesce(func.sum(Book.available_copies), 0),
        )
    ).one()
    return StatsOut(titles=titles, total_copies=total, available_copies=available, issued_copies=total - available)


@app.get("/api/books/{book_id}", response_model=BookOut)
def get_book(book_id: int, db: Session = Depends(get_db)):
    return _get_book(db, book_id)


@app.post("/api/books", response_model=BookOut, status_code=status.HTTP_201_CREATED)
def create_book(payload: BookCreate, db: Session = Depends(get_db)):
    book = Book(**payload.model_dump(), available_copies=payload.total_copies)
    db.add(book)
    db.commit()
    db.refresh(book)
    log.info("book created id=%s title=%r", book.id, book.title)
    return book


@app.put("/api/books/{book_id}", response_model=BookOut)
def update_book(book_id: int, payload: BookUpdate, db: Session = Depends(get_db)):
    book = _get_book(db, book_id)
    changes = payload.model_dump(exclude_unset=True)
    if "total_copies" in changes:
        issued = book.total_copies - book.available_copies
        if changes["total_copies"] < issued:
            raise HTTPException(status_code=409, detail=f"{issued} copies are issued; total cannot be lower")
        book.available_copies = changes["total_copies"] - issued
    for key, value in changes.items():
        setattr(book, key, value)
    db.commit()
    db.refresh(book)
    return book


@app.delete("/api/books/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_book(book_id: int, db: Session = Depends(get_db)):
    book = _get_book(db, book_id)
    if book.available_copies != book.total_copies:
        raise HTTPException(status_code=409, detail="Book has issued copies; return them first")
    db.delete(book)
    db.commit()


@app.post("/api/books/{book_id}/issue", response_model=BookOut)
def issue_book(book_id: int, db: Session = Depends(get_db)):
    book = _get_book(db, book_id)
    if book.available_copies == 0:
        raise HTTPException(status_code=409, detail="No copies available")
    book.available_copies -= 1
    db.commit()
    db.refresh(book)
    LOANS.labels(action="issue").inc()
    return book


@app.post("/api/books/{book_id}/return", response_model=BookOut)
def return_book(book_id: int, db: Session = Depends(get_db)):
    book = _get_book(db, book_id)
    if book.available_copies >= book.total_copies:
        raise HTTPException(status_code=409, detail="All copies are already in the library")
    book.available_copies += 1
    db.commit()
    db.refresh(book)
    LOANS.labels(action="return").inc()
    return book
