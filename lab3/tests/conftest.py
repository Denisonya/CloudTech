import os

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session


@pytest.fixture()
def client():
    # Не разрешаем тестам подключаться к обычной базе приложения.
    if os.getenv("POSTGRES_DB") != "lab3_test":
        pytest.fail("Запустите тесты через bash lab3/check.sh")

    from backend.main import app, get_db
    from backend.database import engine

    # Все изменения теста выполняются внутри транзакции и откатываются после него.
    # savepoint позволяет маршруту вызывать commit(), не фиксируя внешнюю транзакцию.
    with engine.connect() as connection:
        with connection.begin() as transaction:
            with Session(bind=connection, join_transaction_mode="create_savepoint") as session:
                def override_get_db():
                    yield session

                app.dependency_overrides[get_db] = override_get_db
                try:
                    with TestClient(app) as test_client:
                        yield test_client
                finally:
                    app.dependency_overrides.pop(get_db, None)
                    transaction.rollback()
