from datetime import datetime

import pytest


def test_empty_notes_list(client):
    response = client.get("/api/notes")

    assert response.status_code == 200
    assert response.json() == []


def test_create_and_read_note(client):
    response = client.post("/api/notes", json={"text": "  Подготовить отчет  "})

    assert response.status_code == 201
    note = response.json()
    assert note["id"] > 0
    assert note["text"] == "Подготовить отчет"
    assert datetime.fromisoformat(note["created_at"]).tzinfo is not None

    # Новый запрос должен прочитать ту же запись из PostgreSQL.
    response = client.get("/api/notes")
    assert response.status_code == 200
    assert response.json() == [note]


def test_new_notes_come_first(client):
    first = client.post("/api/notes", json={"text": "Первая"})
    second = client.post("/api/notes", json={"text": "Вторая"})

    assert first.status_code == 201
    assert second.status_code == 201
    response = client.get("/api/notes")
    assert response.status_code == 200
    assert [note["id"] for note in response.json()] == [
        second.json()["id"], first.json()["id"],
    ]


def test_note_at_maximum_length(client):
    response = client.post("/api/notes", json={"text": "a" * 500})

    assert response.status_code == 201
    assert response.json()["text"] == "a" * 500


@pytest.mark.parametrize(
    "payload",
    [{"text": ""}, {"text": "   "}, {"text": "a" * 501}, {}],
    ids=["empty", "spaces", "too-long", "missing-text"],
)
def test_invalid_note_is_not_saved(client, payload):
    response = client.post("/api/notes", json=payload)

    assert response.status_code == 422
    response = client.get("/api/notes")
    assert response.status_code == 200
    assert response.json() == []
