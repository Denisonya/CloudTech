# Облегченный актуальный Python, закрепленный по digest.
FROM python:3.12.16-slim-trixie@sha256:b18b261e1b4974b4f321451ad5251ded85abb22c2b8b262da527dda1d031ab30 AS builder

WORKDIR /build
COPY requirements.txt .
RUN python -m venv /venv     && /venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.12.16-slim-trixie@sha256:b18b261e1b4974b4f321451ad5251ded85abb22c2b8b262da527dda1d031ab30

WORKDIR /app
RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system appgroup     && useradd --system --gid appgroup appuser
COPY --from=builder /venv /venv
COPY --chown=appuser:appgroup backend ./backend
ENV PATH="/venv/bin:$PATH"
USER appuser
EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3     CMD python -c "from urllib.request import urlopen; urlopen('http://127.0.0.1:8000/health', timeout=2)"

CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
