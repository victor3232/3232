#!/bin/bash
# ============================================================
#  HITSSSH - start script (baked di image)
#  Runtime Node/Python ada di image. Versi lain di-download
#  otomatis ke folder cache server, jadi aman kalau file
#  server dihapus semua.
# ============================================================
set -o pipefail

APP_DIR="${HITSSSH_APP_DIR:-/home/container}"
CACHE="$APP_DIR/.hitsssh"
IMAGE_NODE="${HITSSSH_IMAGE_NODE:-/opt/node/22}"
IMAGE_PYTHON="${HITSSSH_IMAGE_PYTHON:-python3}"

mkdir -p "$CACHE" 2>/dev/null
cd "$APP_DIR" || exit 1

NODE_VER="${NODE_VERSION:-22}"
PY_VER="${PYTHON_VERSION:-3.12}"

[ "$NODE_VER" = "lts" ] && NODE_VER="22"
NODE_MAJOR="$(echo "$NODE_VER" | cut -d. -f1)"
PY_VER="$(echo "$PY_VER" | cut -d. -f1,2)"

# ---------------- Node.js ----------------
NODE_BIN=""
if [ "$NODE_MAJOR" = "22" ] && [ -x "$IMAGE_NODE/bin/node" ]; then
  NODE_BIN="$IMAGE_NODE/bin"
elif [ -x "$CACHE/node-$NODE_MAJOR/bin/node" ]; then
  NODE_BIN="$CACHE/node-$NODE_MAJOR/bin"
else
  echo "[startup] Node.js $NODE_MAJOR belum ada, mengunduh..."
  case "$(uname -m)" in
    x86_64|amd64) NA="x64" ;;
    aarch64|arm64) NA="arm64" ;;
    *) NA="" ;;
  esac
  if [ -n "$NA" ]; then
    FILE=$(curl -fsSL "https://nodejs.org/dist/latest-v${NODE_MAJOR}.x/" 2>/dev/null \
      | grep -oE "node-v${NODE_MAJOR}\.[0-9]+\.[0-9]+-linux-${NA}\.tar\.xz" | head -n1)
    if [ -n "$FILE" ] && curl -fL "https://nodejs.org/dist/latest-v${NODE_MAJOR}.x/${FILE}" -o /tmp/hitsssh-node.tar.xz \
      && mkdir -p "$CACHE/node-$NODE_MAJOR" \
      && tar -xJf /tmp/hitsssh-node.tar.xz -C "$CACHE/node-$NODE_MAJOR" --strip-components=1; then
      NODE_BIN="$CACHE/node-$NODE_MAJOR/bin"
    fi
    rm -f /tmp/hitsssh-node.tar.xz
  fi
fi

if [ -z "$NODE_BIN" ]; then
  echo "[startup] WARNING: Node.js $NODE_MAJOR gagal disiapkan, memakai Node bawaan image."
  NODE_BIN="$IMAGE_NODE/bin"
fi

# ---------------- Python ----------------
PY=""
if [ "$PY_VER" = "3.12" ] && command -v "$IMAGE_PYTHON" >/dev/null 2>&1; then
  PY="$IMAGE_PYTHON"
elif [ -x "$CACHE/python-$PY_VER/bin/python3" ]; then
  PY="$CACHE/python-$PY_VER/bin/python3"
else
  case "$PY_VER" in
    3.10) PY_TAG="20261009"; PY_FULL="3.10.22" ;;
    3.11) PY_TAG="20261110"; PY_FULL="3.11.18" ;;
    3.13) PY_TAG="20261110"; PY_FULL="3.13.18" ;;
    3.14) PY_TAG="20261110"; PY_FULL="3.14.10" ;;
    *)    PY_TAG="" ;;
  esac

  if [ -n "$PY_TAG" ]; then
    echo "[startup] Python $PY_VER belum ada, mengunduh..."
    case "$(uname -m)" in
      x86_64|amd64) PA="x86_64" ;;
      aarch64|arm64) PA="aarch64" ;;
      *) PA="" ;;
    esac
    if [ -n "$PA" ]; then
      PY_URL="https://github.com/astral-sh/python-build-standalone/releases/download/${PY_TAG}/cpython-${PY_FULL}%2B${PY_TAG}-${PA}-unknown-linux-gnu-install_only_stripped.tar.gz"
      if curl -fL "$PY_URL" -o /tmp/hitsssh-python.tar.gz \
        && mkdir -p "$CACHE/python-$PY_VER" \
        && tar -xzf /tmp/hitsssh-python.tar.gz -C "$CACHE/python-$PY_VER" --strip-components=1; then
        PY="$CACHE/python-$PY_VER/bin/python3"
      fi
      rm -f /tmp/hitsssh-python.tar.gz
    fi
  fi
fi

if [ -z "$PY" ]; then
  echo "[startup] WARNING: Python $PY_VER gagal disiapkan, memakai Python bawaan image."
  PY="$IMAGE_PYTHON"
fi

# ---------------- PATH ----------------
PY_DIR=""
case "$PY" in
  */*) PY_DIR="$(dirname "$PY")" ;;
esac
export PATH="${NODE_BIN}${PY_DIR:+:$PY_DIR}:${HOME}/.local/bin:$PATH"
if [ -d "$(dirname "$NODE_BIN")/../lib/node_modules" ]; then
  export NODE_PATH="$(cd "$(dirname "$NODE_BIN")/../lib/node_modules" && pwd)"
fi

# ---------------- Cloudflare Tunnel ----------------
if [ "${ENABLE_CF_TUNNEL:-false}" = "true" ] || [ "${ENABLE_CF_TUNNEL:-false}" = "1" ]; then
  if [ -n "${CF_TOKEN:-}" ]; then
    CF_BIN="$(command -v cloudflared 2>/dev/null || true)"
    if [ -n "$CF_BIN" ]; then
      pkill -x cloudflared 2>/dev/null || true
      nohup "$CF_BIN" tunnel run --token "$CF_TOKEN" \
        > "$APP_DIR/.cloudflared.log" 2>&1 &
      echo "[startup] Cloudflare Tunnel aktif (log: .cloudflared.log)"
    else
      echo "[startup] ERROR: cloudflared tidak ada di image."
    fi
  else
    echo "[startup] WARNING: ENABLE_CF_TUNNEL aktif tapi CF_TOKEN kosong."
  fi
fi

# ---------------- Dependency otomatis (sekali) ----------------
if [ "${AUTO_INSTALL_DEPS:-true}" = "true" ] || [ "${AUTO_INSTALL_DEPS:-true}" = "1" ]; then
  if [ -f package.json ] && command -v npm >/dev/null 2>&1; then
    NPM_MARK="$CACHE/.npm-$(md5sum package.json | cut -d' ' -f1)"
    if [ ! -f "$NPM_MARK" ] || [ ! -d node_modules ]; then
      echo "[startup] Menjalankan npm install..."
      npm install --no-audit --no-fund && mkdir -p node_modules && touch "$NPM_MARK"
    fi
  fi

  if [ -f requirements.txt ] && command -v "$PY" >/dev/null 2>&1; then
    PYVER_ACTUAL=$("$PY" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null || echo unknown)
    PIP_MARK="$CACHE/.pip-${PYVER_ACTUAL}-$(md5sum requirements.txt | cut -d' ' -f1)"
    if [ ! -f "$PIP_MARK" ]; then
      echo "[startup] Menjalankan pip install --user -r requirements.txt..."
      PIP_FLAGS="--user"
      "$PY" -m pip install --help 2>/dev/null | grep -q -- "--break-system-packages" && PIP_FLAGS="$PIP_FLAGS --break-system-packages"
      "$PY" -m pip install $PIP_FLAGS -r requirements.txt && touch "$PIP_MARK"
    fi
  fi
fi

# ---------------- Pilih perintah start ----------------
CMD="${STARTUP_CMD:-}"

if [ -z "$CMD" ]; then
  if [ -f package.json ] && [ -f index.js ]; then
    CMD="node index.js"
  elif [ -f package.json ]; then
    CMD="npm start"
  elif [ -f main.py ]; then
    CMD="python main.py"
  elif [ -f app.py ]; then
    CMD="python app.py"
  elif [ -f bot.py ]; then
    CMD="python bot.py"
  fi
  [ -n "$CMD" ] && echo "[startup] Auto-detect: $CMD"
fi

echo "=========================================="
echo "               H I T S S S H              "
echo " Node.js : $(node -v 2>/dev/null || echo '-')"
echo " Python  : $("$PY" --version 2>&1 | awk '{print $2}')"
echo "=========================================="
echo "System Ready."

if [ -n "$CMD" ]; then
  exec bash -c "$CMD"
else
  echo "[startup] Tidak ada app terdeteksi & STARTUP_CMD kosong: masuk mode shell."
  exec bash
fi
