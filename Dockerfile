FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libssl3t64 \
    libstdc++6 \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 telegram-bot-api /usr/local/bin/telegram-bot-api

RUN useradd --create-home --uid 10001 appuser \
    && mkdir -p /data \
    && chown -R appuser:appuser /data

USER appuser
WORKDIR /data

EXPOSE 8081

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -sS -o /dev/null http://127.0.0.1:8081/ || exit 1

CMD ["sh", "-c", "exec telegram-bot-api --local --api-id=\"$TELEGRAM_API_ID\" --api-hash=\"$TELEGRAM_API_HASH\" --http-port=\"${TELEGRAM_API_HTTP_PORT:-8081}\""]
