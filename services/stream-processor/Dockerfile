FROM python:3.13-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.13-slim

RUN groupadd -r appuser && useradd -r -g appuser -u 10001 appuser

WORKDIR /app

COPY --from=builder /root/.local /home/appuser/.local
COPY src/ ./src/

RUN chown -R appuser:appuser /app

USER appuser

ENV PATH=/home/appuser/.local/bin:$PATH

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD pgrep -f "src.main" || exit 1

CMD ["python", "-m", "src.main"]