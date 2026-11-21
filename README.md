# Hitsssh - image runtime milik sendiri

Image ini menggantikan image runtime egg sebelumnya yang bergantung pada GHCR akun lain.

- **Python 3.12** bawaan (fallback kalau `PYTHON_VERSION` dikosongkan)
- **Node.js** dan **Python versi lain** di-install per server oleh egg
  (dari nodejs.org dan python-build-standalone, sumber resmi)
- **cloudflared** sudah di-bake di image
- build tools (gcc/g++/make), git, curl, tini, iproute2

Repo: `victor3232/3232`
Image: `ghcr.io/victor3232/3232:latest`

## Build otomatis (GitHub Actions)

Workflow `build-image` jalan otomatis setiap push ke branch `main`
(atau lewat tab **Actions** -> **Run workflow**).

Setelah build selesai:

1. Buka halaman repo -> **Packages** -> pilih package `3232`.
2. **Package settings** -> **Change visibility** -> **Public**.
   Wajib, supaya Wings bisa pull tanpa `docker login`.
3. Image siap dipakai: `ghcr.io/victor3232/3232:latest`

Tidak perlu membuat token manual. Actions memakai `GITHUB_TOKEN`
dengan permission `packages: write` yang sudah diatur di workflow.

## Build manual (kalau punya Docker)

```bash
echo "$GH_TOKEN" | docker login ghcr.io -u victor3232 --password-stdin

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/victor3232/3232:latest \
  --push .
```

Token harus Personal Access Token (classic) dengan scope
`write:packages` (+ `read:packages`). Jangan pakai password akun.

## Pakai di egg

```bash
bash /root/set-own-image.sh ghcr.io/victor3232/3232:latest
```

Atau edit manual `/root/egg-hitsssh.json` pada bagian `docker_images`.

Setelah itu import ulang egg di panel, lalu **Reinstall** server yang sudah ada.

## Catatan

- Kalau butuh **ffmpeg** (bot musik), tambahkan `ffmpeg` ke daftar
  `apt-get install` di Dockerfile, lalu push ulang.
- Kalau butuh update cloudflared, jalankan ulang workflow
  (build selalu ambil rilis terbaru).
- Image ini tidak menyimpan data server. Data tetap di volume
  `/home/container` milik Pterodactyl.

## File egg

Egg siap import ada di repo ini: [`egg-hitsssh.json`](./egg-hitsssh.json)

Di VPS juga tersedia di: `/root/egg-hitsssh.json`
