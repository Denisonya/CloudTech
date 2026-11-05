def test_health(client):
    response = client.get("/health")

    assert response.status_code == 503
    assert response.json() == {"status": "ok"}
