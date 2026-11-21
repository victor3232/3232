# Hitsssh runtime image
# Node.js 22 + Python 3.12 + cloudflared, siap pakai.
# Versi Node/Python lain di-download otomatis oleh start.sh
# (disimpan di folder cache server), jadi area file server
# boleh dikosongkan tanpa merusak start.

FROM python:3.12-slim-bookworm

ARG TARGETARCH
ARG NODE_MAJOR=22
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

# Node.js bawaan image
RUN case "${TARGETARCH:-amd64}" in \
      amd64|"") NODE_ARCH=x64 ;; \
      arm64)    NODE_ARCH=arm64 ;; \
      *) echo "arsitektur tidak didukung: ${TARGETARCH}" && exit 1 ;; \
    esac \
 && FILE=$(curl -fsSL "https://nodejs.org/dist/latest-v${NODE_MAJOR}.x/" \
      | grep -oE "node-v${NODE_MAJOR}\.[0-9]+\.[0-9]+-linux-${NODE_ARCH}\.tar\.xz" | head -n1) \
 && test -n "$FILE" \
 && mkdir -p "/opt/node/${NODE_MAJOR}" \
 && curl -fL "https://nodejs.org/dist/latest-v${NODE_MAJOR}.x/${FILE}" -o /tmp/node.tar.xz \
 && tar -xJf /tmp/node.tar.xz -C "/opt/node/${NODE_MAJOR}" --strip-components=1 \
 && rm -f /tmp/node.tar.xz \
 && "/opt/node/${NODE_MAJOR}/bin/node" -v

# cloudflared
RUN case "${TARGETARCH:-amd64}" in \
      amd64|"") CF_ARCH=amd64 ;; \
      arm64)    CF_ARCH=arm64 ;; \
      *) echo "arsitektur tidak didukung: ${TARGETARCH}" && exit 1 ;; \
    esac \
 && curl -fsSL --retry 3 \
      "https://github.com/cloudflare/cloudflared/releases/${CLOUDFLARED_VERSION}/download/cloudflared-linux-${CF_ARCH}" \
      -o /usr/local/bin/cloudflared \
 && chmod +x /usr/local/bin/cloudflared \
 && cloudflared --version

# start script + entrypoint bawaan image
COPY --chown=container:container start.sh /opt/hitsssh/start.sh
COPY --chown=container:container entrypoint.sh /entrypoint.sh
RUN chmod +x /opt/hitsssh/start.sh /entrypoint.sh

ENV PATH="/opt/node/${NODE_MAJOR}/bin:${PATH}"

WORKDIR /home/container
STOPSIGNAL SIGINT

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/entrypoint.sh"]
