def test_health(client):
    response = client.get("/health")

    # Намеренная ошибка для проверки блокировки сборки в CI.
    assert response.status_code == 503
    assert response.json() == {"status": "ok"}
