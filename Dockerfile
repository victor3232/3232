# Hitsssh - runtime image
# Isi: Python 3.12 (fallback), build tools, git/curl, cloudflared
# Node.js & Python versi pilihan tetap di-install per server oleh egg
# (Node dari nodejs.org, Python dari python-build-standalone).

FROM python:3.12-slim-bookworm

ARG TARGETARCH=amd64
ARG CLOUDFLARED_VERSION=latest

ENV DEBIAN_FRONTEND=noninteractive \
    USER=container \
    HOME=/home/container \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git tar xz-utils unzip \
      gcc g++ make pkg-config \
      libffi-dev libssl-dev zlib1g-dev \
      procps tini iproute2 dnsutils \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m -d /home/container -s /bin/bash container

# cloudflared (multi-arch: amd64 / arm64)
RUN case "${TARGETARCH}" in \
      amd64|"") CF_ARCH=amd64 ;; \
      arm64)    CF_ARCH=arm64 ;; \
      *) echo "arsitektur tidak didukung: ${TARGETARCH}" && exit 1 ;; \
    esac \
 && curl -fsSL --retry 3 \
      "https://github.com/cloudflare/cloudflared/releases/${CLOUDFLARED_VERSION}/download/cloudflared-linux-${CF_ARCH}" \
      -o /usr/local/bin/cloudflared \
 && chmod +x /usr/local/bin/cloudflared \
 && cloudflared --version

COPY --chown=container:container entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /home/container
STOPSIGNAL SIGINT

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/entrypoint.sh"]
