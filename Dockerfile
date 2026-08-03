# =============================================================================
# Telegram Bot API Server — Multi-stage Dockerfile
# Builds the official Telegram Bot API server from the tdlib/telegram-bot-api
# source (pinned to a specific commit) using TDLib.
# =============================================================================

# -------------------------- Builder Stage ------------------------------------
FROM ubuntu:24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG TELEGRAM_API_REF=adfd7f6a8e990272851777eeb3ae0def4216f161

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    gperf \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libreadline-dev \
    libconfig-dev \
    libssl-dev \
    libleveldb-dev \
    libsqlite3-dev \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# Build TDLib
RUN git clone --depth 1 --branch master https://github.com/tdlib/tdlib.git /opt/tdlib \
    && mkdir -p /opt/tdlib/build \
    && cd /opt/tdlib/build \
    && cmake -DCMAKE_BUILD_TYPE=Release .. \
    && cmake --build . --target install -j$(nproc) \
    && ldconfig

# Build Telegram Bot API server from the pinned source
RUN git clone --depth 1 --branch master https://github.com/tdlib/telegram-bot-api.git /opt/telegram-bot-api \
    && cd /opt/telegram-bot-api \
    && git fetch --depth 1 origin ${TELEGRAM_API_REF} \
    && git checkout ${TELEGRAM_API_REF} \
    && mkdir -p build \
    && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release .. \
    && cmake --build . --target telegram-bot-api -j$(nproc)

# -------------------------- Runtime Stage ------------------------------------
FROM ubuntu:24.04 AS runtime

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libssl3t64 \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# Copy the built binary from the builder stage
COPY --from=builder /opt/telegram-bot-api/build/telegram-bot-api /usr/local/bin/telegram-bot-api

# Create a non-root user to run the server
RUN useradd --create-home --uid 10001 appuser \
    && mkdir -p /data \
    && chown -R appuser:appuser /data

USER appuser
WORKDIR /data

EXPOSE 8081

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -sf http://127.0.0.1:8081/ || exit 1

CMD ["sh", "-c", "exec telegram-bot-api --local --api-id=\"$TELEGRAM_API_ID\" --api-hash=\"$TELEGRAM_API_HASH\" --http-port=\"${TELEGRAM_API_HTTP_PORT:-8081}\""]
