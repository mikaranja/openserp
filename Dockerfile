# Build
FROM --platform=$BUILDPLATFORM golang:1.26.11-bookworm AS builder

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY . .
ARG TARGETOS
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-amd64} go build -trimpath -ldflags="-s -w" -o /app/openserp .

# `chromedp/headless-shell:stable` also works here
FROM chromedp/headless-shell:stable@sha256:381353d3530ab9d579d2fe8b9c0f4519c995617f5a71daf6bb649e2d12005bd9

WORKDIR /usr/src/app

# wget: used by HEALTHCHECK (localhost, no TLS, so ca-certificates not required).
# mupdf-tools: mutool reads the text layer of PDF URLs for /extract.
# tini: reaps orphaned Chrome children, which would otherwise pile up as zombies when openserp is PID 1.
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends wget mupdf-tools tini \
  && rm -rf /var/lib/apt/lists/* \
  && getent passwd chrome >/dev/null 2>&1 || useradd --create-home --uid 1001 --shell /bin/bash chrome \
  && chown chrome:chrome /usr/src/app

COPY --from=builder /app/openserp /usr/local/bin/openserp
COPY --chown=chrome:chrome config.yaml ./config.yaml

# Rod's launcher.LookPath does not know about /headless-shell/headless-shell.
# Viper auto-binds OPENSERP_APP_BROWSER_PATH to app.browser_path, so this pins the binary and avoids Rod's runtime chromium auto-download (which would fail in this non-root, network-restricted image).
ENV OPENSERP_APP_BROWSER_PATH=/headless-shell/headless-shell \
  OPENSERP_SERVER_HOST=0.0.0.0 \
  OPENSERP_SERVER_PORT=7000

USER chrome

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget --quiet --tries=1 --spider "http://127.0.0.1:${OPENSERP_SERVER_PORT}/health" || exit 1

# -s keeps reaping when another init is PID 1 (`docker run --init`, compose `init: true`).
ENTRYPOINT ["/usr/bin/tini", "-s", "--", "openserp"]
