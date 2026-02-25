# =============================================================================
# Eastsea Node - Multi-stage Dockerfile
# REQ-104: Docker 즉시 실행 (docker run 원클릭)
# =============================================================================

# Stage 1: Build with official Zig binary
FROM alpine:3.20 AS builder

ARG ZIG_VERSION=0.14.1

RUN apk add --no-cache curl xz musl-dev && \
    curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-$(uname -m)-${ZIG_VERSION}.tar.xz" \
    | tar xJ -C /opt && \
    ln -s /opt/zig-linux-*-${ZIG_VERSION}/zig /usr/local/bin/zig

WORKDIR /build
COPY build.zig build.zig.zon* ./
COPY src/ src/

RUN zig build -Doptimize=ReleaseSafe 2>&1 && \
    ls -la zig-out/bin/

# Stage 2: Minimal runtime
FROM alpine:3.20

RUN apk add --no-cache tini curl \
    && addgroup -S eastsea \
    && adduser -S eastsea -G eastsea \
    && mkdir -p /data/eastsea \
    && chown eastsea:eastsea /data/eastsea

COPY --from=builder /build/zig-out/bin/eastsea /usr/local/bin/eastsea
COPY --from=builder /build/zig-out/bin/eastsea-production /usr/local/bin/eastsea-production
RUN chmod +x /usr/local/bin/eastsea /usr/local/bin/eastsea-production

# 기본 설정 파일
COPY <<EOF /data/eastsea/config.json
{
  "node_address": "0.0.0.0",
  "node_port": 8000,
  "rpc_port": 8545,
  "data_dir": "/data/eastsea",
  "is_validator": true,
  "max_peers": 50,
  "log_level": "info"
}
EOF
RUN chown eastsea:eastsea /data/eastsea/config.json

USER eastsea
WORKDIR /data/eastsea

EXPOSE 8000 8545 9000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -sf http://localhost:8545/ || exit 1

ENTRYPOINT ["tini", "--"]
CMD ["eastsea", "--demo"]
