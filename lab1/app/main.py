import os
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import Base, SessionLocal, engine
from app.models import Note
from app.schemas import NoteCreate, NoteRead


INSTANCE_ID = os.getenv("INSTANCE_ID", "unknown")


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="Notes Service",
    lifespan=lifespan,
)


@app.middleware("http")
async def add_backend_instance_header(request, call_next):
    response = await call_next(request)

    if request.url.path.startswith("/api"):
        response.headers["Backend-Instance"] = INSTANCE_ID

    return response


def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()


@app.get("/health")
def health():
    return {
        "status": "ok",
        "instance": INSTANCE_ID,
    }


@app.get("/api/notes", response_model=list[NoteRead])
def get_notes(db: Session = Depends(get_db)):
    statement = select(Note).order_by(Note.id.desc())
    return db.scalars(statement).all()


@app.post(
    "/api/notes",
    response_model=NoteRead,
    status_code=status.HTTP_201_CREATED,
)
def create_note(note_data: NoteCreate, db: Session = Depends(get_db)):
    text = note_data.text.strip()

    if not text:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Text cannot be empty",
        )

    note = Note(text=text)

    db.add(note)
    db.commit()
    db.refresh(note)

    return note