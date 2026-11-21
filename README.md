# Hitsssh runtime image

Image ini menggantikan image runtime egg sebelumnya yang bergantung pada GHCR akun lain.

## Isi image
- **Node.js 22** built-in (`/opt/node/22`)
- **Python 3.12** built-in
- **cloudflared** built-in
- gcc/g++/make, git, curl, tini, iproute2 (untuk build modul native)
- `/opt/hitsssh/start.sh` (auto-detect app + tunnel + dependency)

## Kenapa tidak perlu `.runtime` lagi
Runtime utama ada **di dalam image**, bukan di folder server. Jadi:
- area file server boleh dikosongkan lalu upload ulang script
- tidak ada folder `.runtime` yang harus dijaga
- install server jadi cepat (tanpa download Node/Python/cloudflared)

Versi selain default (Node 18/20/24, Python 3.10/3.11/3.13/3.14)
di-download otomatis saat start pertama ke `<server>/.hitsssh/` (cache).
Kalau folder itu terhapus, akan di-download ulang otomatis.

## Build otomatis (GitHub Actions)

Workflow `build-image` jalan otomatis setiap push ke `main`
(atau lewat tab **Actions** -> **Run workflow**).

Tag yang dihasilkan:
- `ghcr.io/victor3232/3232:v2`
- `ghcr.io/victor3232/3232:latest`

Setelah build selesai:

1. Buka repo -> **Packages** -> package `3232`.
2. **Package settings** -> **Change visibility** -> **Public**
   (supaya Wings bisa pull tanpa `docker login`).

## Build manual (kalau punya Docker)

```bash
echo "$GH_TOKEN" | docker login ghcr.io -u victor3232 --password-stdin

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/victor3232/3232:v2 \
  -t ghcr.io/victor3232/3232:latest \
  --push .
```

Token harus Personal Access Token (classic) dengan scope
`write:packages` (+ `read:packages`). Jangan pakai password akun.

## Pakai di egg

```bash
bash /root/set-own-image.sh ghcr.io/victor3232/3232:v2
```

Egg siap import: [`egg-hitsssh.json`](./egg-hitsssh.json)

## Catatan
- Butuh **ffmpeg** (bot musik)? tambahkan `ffmpeg` ke `apt-get install` di Dockerfile lalu push ulang.
- Data server tetap di volume `/home/container` milik Pterodactyl.
