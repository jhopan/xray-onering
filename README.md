# xray-onering (JhopanStore)

Build **Xray-core** dengan patch SNI OneRing — `onering:REAL:BUG`.

- TCP / address → bug domain (CDN/host gratis)
- TLS SNI → real domain milikmu
- **1 file diubah, +28 baris** di Xray-core
- Kit ini: patch + script saja — bukan fork penuh Xray

| | |
|---|---|
| **Developer** | **JhopanStore** |
| **Repo** | https://github.com/jhopan/xray-onering |
| **Engine base** | [XTLS/Xray-core](https://github.com/XTLS/Xray-core) |
| **Credit metode** | [dharak36/xray-onering](https://github.com/dharak36/xray-onering) |
| **Default base** | Xray-core `v26.6.22` (bisa diganti) |
| **License kit** | MIT |

---

## Download binary (prebuilt)

> **https://github.com/jhopan/xray-onering/releases**

| File | Platform | Cocok untuk |
|---|---|---|
| `xray.linux.arm64.onering` | Linux ARM64 | OpenWrt / STB / Pi / VPS ARM |
| `xray.linux.amd64.onering` | Linux x64 | VPS / server / desktop Linux |
| `xray.linux.armv7.onering` | Linux ARMv7 | OpenWrt 32-bit (armv7) / router lama |
| `xray.windows.amd64.onering.exe` | Windows x64 | Desktop / laptop Windows |
| `xray.windows.arm64.onering.exe` | Windows ARM64 | Surface Pro X / Snapdragon PC |
| `SHA256SUMS.txt` | — | verifikasi integritas |

Verifikasi:
```bash
sha256sum -c SHA256SUMS.txt
```

---

## Isi repo

```
xray-onering/
├── onering.patch   # patch OneRing (+28 baris, 1 file)
├── apply.sh        # pilih versi → clone Xray → apply patch
├── build.sh        # --ver → apply + build binary
├── verify.sh       # cek patch / tree / binary
├── LICENSE         # MIT © JhopanStore
└── README.md
```

Build mengunduh Xray-core dari repo resmi XTLS, patch, lalu compile.  
`Xray-core/` dan `dist/` di-gitignore (tidak di-push).

---

## Syarat build dari source

| Syarat | Keterangan |
|---|---|
| Go 1.24+ | `go version` |
| Git | clone Xray base |
| Internet | saat pertama `apply.sh` |
| Windows | pakai Git Bash / WSL untuk jalankan `.sh` |

---

## Build

### Satu perintah (disarankan)

```bash
# pilih versi → unduh Xray → apply OneRing → build
bash build.sh --ver v26.6.22 linux-arm64
bash build.sh -v 26.6.22 all
bash build.sh --force --ver v26.7.1 all
```

### Dua langkah

```bash
# 1. unduh + patch
bash apply.sh v26.6.22

# 2. build
bash build.sh linux-arm64
```

### Semua platform sekaligus

```bash
bash build.sh --ver v26.6.22 all
# → dist/xray.linux.arm64.onering
# → dist/xray.linux.amd64.onering
# → dist/xray.windows.amd64.onering.exe
```

Target lain (manual):

```bash
bash build.sh linux-arm        # ARMv7 32-bit
bash build.sh windows-arm64    # Windows ARM
bash build.sh host             # OS sekarang
bash build.sh custom darwin arm64   # macOS Apple Silicon
```

### Target lengkap

| Target | GOOS | GOARCH | Catatan |
|---|---|---|---|
| `host` | (detect) | (detect) | OS sekarang |
| `linux-arm64` | linux | arm64 | |
| `linux-amd64` | linux | amd64 | |
| `linux-arm` | linux | arm | GOARM=7 |
| `windows-amd64` | windows | amd64 | |
| `windows-arm64` | windows | arm64 | |
| `all` | — | — | arm64+amd64 linux + win amd64 |
| `custom goos goarch [extra]` | bebas | bebas | |

Output: `dist/xray.<os>.<arch>.onering[.exe]`

### Versi Xray

```bash
# lihat tag yang tersedia
bash apply.sh --list

# ganti versi
bash build.sh --force --ver v26.7.1 all

# default kalau tidak ada --ver: v26.6.22
```

### Verifikasi hasil

```bash
bash verify.sh
./dist/xray.linux.amd64.onering version
# → Xray 26.6.22 (Xray, Penetrates Everything.)
```

---

## Cara OneRing bekerja

```
Config serverName: "onering:neva.jhopanstore.my.id:support.zoom.us"
                              │real domain             │bug domain
                              ↓                        ↓
TCP connect  ─────────────────────────────────► bug domain IP (CDN)
TLS SNI      ─────────────────────────────────► real domain
WS Host      ─────────────────────────────────► real domain
```

ISP hanya melihat koneksi ke CDN publik (bug domain). Server menerima TLS dengan SNI real domain milikmu.

---

## Config Xray

```json
{
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "support.zoom.us",
        "port": 443,
        "users": [{"id": "UUID-MU", "encryption": "none"}]
      }]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "tlsSettings": {
        "serverName": "onering:neva.jhopanstore.my.id:support.zoom.us",
        "fingerprint": ""
      },
      "wsSettings": {
        "path": "/vless",
        "headers": {"Host": "neva.jhopanstore.my.id"}
      }
    }
  }]
}
```

> Xray v26+: jangan `allowInsecure: true`. Pakai `fingerprint: ""`.

| Field | Value |
|---|---|
| `address` | bug domain (CDN) |
| `serverName` | `onering:REAL:BUG` |
| WS `Host` | real domain |

---

## Deploy

### VPS / server Linux

```bash
scp dist/xray.linux.amd64.onering root@SERVER:/usr/local/bin/xray
ssh root@SERVER 'chmod +x /usr/local/bin/xray && xray version'
systemctl restart xray  # atau marzban / v2ray-agent
```

### OpenWrt (arm64)

```bash
scp dist/xray.linux.arm64.onering root@192.168.1.1:/tmp/xray
ssh root@192.168.1.1 '
  cp /usr/bin/xray /usr/bin/xray.bak
  mv /tmp/xray /usr/bin/xray
  chmod +x /usr/bin/xray
  xray version
  /etc/init.d/passwall restart
'
```

### OpenWrt (ARMv7 32-bit)

```bash
scp dist/xray.linux.armv7.onering root@ROUTER:/tmp/xray
# sama seperti arm64 di atas
```

### Windows

```bat
dist\xray.windows.amd64.onering.exe run -c config.json
```

---

## Update base Xray ke versi baru

```bash
# lihat tag terbaru
bash apply.sh --list

# build dengan versi baru (re-clone otomatis)
bash build.sh --force --ver vNEW all
bash verify.sh
```

Kalau patch conflict (Xray ubah `parseServerName`):

```bash
cd Xray-core
git apply --reject ../onering.patch
# edit manual ParseOneRing + parseServerName
# lihat: transport/internet/tls/config.go
git add transport/internet/tls/config.go
git commit -m "OneRing"
git format-patch -1 HEAD --stdout > ../onering.patch
cd ..
bash build.sh all
```

---

## Kembangkan lebih lanjut

Repo ini dirancang agar mudah dikembangkan:

| Mau tambah | Cara |
|---|---|
| Platform baru (macOS, FreeBSD) | `bash build.sh custom darwin arm64` |
| Versi Xray baru | `bash build.sh --force --ver vX.Y.Z all` |
| Fitur Xray tambahan | fork `Xray-core`, tambah patch, update `onering.patch` |
| AAR Android | pakai `libxray-mobile` + gomobile (repo terpisah) |
| CI auto-build | tambah `.github/workflows/build.yml` (lihat bawah) |

### Contoh GitHub Actions (opsional)

```yaml
name: Build
on:
  push:
    tags: ['*']
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.26'
      - run: bash build.sh --ver v26.6.22 all
      - uses: softprops/action-gh-release@v2
        with:
          files: dist/*
```

---

## Credits

| | |
|---|---|
| **Developer kit** | **JhopanStore** |
| **Metode OneRing** | [dharak36/xray-onering](https://github.com/dharak36/xray-onering) |
| **Engine** | [XTLS/Xray-core](https://github.com/XTLS/Xray-core) (MPL-2.0) |

Kit ini (script, patch, docs) lisensi **MIT**.  
Binary hasil build mengandung Xray-core (MPL-2.0 upstream).
