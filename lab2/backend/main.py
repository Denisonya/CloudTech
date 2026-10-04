from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from backend.database import Base, SessionLocal, engine
from backend.models import Note
from backend.schemas import NoteCreate, NoteRead


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="Notes Service",
    lifespan=lifespan,
)


def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()


# Проверка работы Backend для HEALTHCHECK в Docker
@app.get("/health")
def health(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    return {"status": "ok"}


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
    note_text = note_data.text.strip()

    if not note_text:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Text cannot be empty",
        )

    note = Note(text=note_text)

    db.add(note)
    db.commit()
    db.refresh(note)

    return note
