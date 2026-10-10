from contextlib import asynccontextmanager
from fastapi import Depends, FastAPI, HTTPException, Response
from sqlalchemy import Integer, String, Text, create_engine, text
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker
from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "sqlite:///./dev.db"
    app_env: str = "development"
    log_level: str = "INFO"


settings = Settings()
is_sqlite = settings.database_url.startswith("sqlite")
if settings.app_env.lower() in {"production", "prod"} and is_sqlite:
    raise RuntimeError("Production requires DATABASE_URL to point to PostgreSQL; refusing ephemeral SQLite storage.")

connect_args = {"check_same_thread": False} if is_sqlite else {}
engine = create_engine(
    settings.database_url,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=10,
    connect_args=connect_args,
)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


class Note(Base):
    __tablename__ = "notes"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    body: Mapped[str] = mapped_column(Text, default="", nullable=False)


class NoteCreate(BaseModel):
    title: str = Field(min_length=1, max_length=160)
    body: str = Field(default="", max_length=5000)


class NoteRead(BaseModel):
    id: int
    title: str
    body: str


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Local development stays convenient. Production schema changes are applied by
    # the one-off Helm migration Job, not concurrently by every application replica.
    if is_sqlite and settings.app_env.lower() not in {"production", "prod"}:
        Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="Three-Tier Platform API", lifespan=lifespan)


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz(response: Response, db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        return {"status": "ready"}
    except Exception:
        response.status_code = 503
        return {"status": "not_ready"}


@app.get("/api/v1/notes", response_model=list[NoteRead])
def list_notes(db: Session = Depends(get_db)):
    return db.query(Note).order_by(Note.id.desc()).limit(100).all()


@app.post("/api/v1/notes", response_model=NoteRead, status_code=201)
def create_note(payload: NoteCreate, db: Session = Depends(get_db)):
    note = Note(title=payload.title.strip(), body=payload.body)
    if not note.title:
        raise HTTPException(status_code=422, detail="Title cannot be blank")
    db.add(note)
    db.commit()
    db.refresh(note)
    return note
