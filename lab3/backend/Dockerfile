# Исходный полный образ для демонстрации уязвимостей до исправления.
FROM python:3.12.7@sha256:8d97a0ab83113f8984517f14492f57186d943db7815682cab9d820c9c0a8c998 AS builder

WORKDIR /build
COPY requirements.txt .
RUN python -m venv /venv     && /venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.12.7@sha256:8d97a0ab83113f8984517f14492f57186d943db7815682cab9d820c9c0a8c998

WORKDIR /app
RUN groupadd --system appgroup     && useradd --system --gid appgroup appuser
COPY --from=builder /venv /venv
COPY --chown=appuser:appgroup backend ./backend
ENV PATH="/venv/bin:$PATH"
USER appuser
EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3     CMD python -c "from urllib.request import urlopen; urlopen('http://127.0.0.1:8000/health', timeout=2)"

CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
