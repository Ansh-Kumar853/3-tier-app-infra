from fastapi.testclient import TestClient
from app.main import app


def test_healthz():
    with TestClient(app) as client:
        response = client.get("/healthz")
        assert response.status_code == 200
        assert response.json()["status"] == "ok"


def test_notes_crud_create_and_list():
    with TestClient(app) as client:
        response = client.post("/api/v1/notes", json={"title": "CI test note", "body": "Created by test"})
        assert response.status_code == 201
        created = response.json()
        assert created["title"] == "CI test note"
        assert created["body"] == "Created by test"

        listed = client.get("/api/v1/notes")
        assert listed.status_code == 200
        assert any(note["id"] == created["id"] for note in listed.json())


def test_note_title_is_required():
    with TestClient(app) as client:
        response = client.post("/api/v1/notes", json={"title": "", "body": "invalid"})
        assert response.status_code == 422
