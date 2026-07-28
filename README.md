# xray-onering

> **Xray-core** dengan patch OneRing SNI — bypass DPI tanpa domain pointing ke Cloudflare.

```
onering:REAL_DOMAIN:BUG_DOMAIN
   ↓                    ↓
TLS SNI             TCP / address
(real milikmu)      (CDN/bug gratis)
```

ISP hanya melihat koneksi ke CDN publik. Server menerima TLS dengan SNI domain kamu sendiri.

---

<div align="center">

| | |
|---|---|
| 👨‍💻 **Developer** | JhopanStore |
| 🔧 **Engine** | [XTLS/Xray-core](https://github.com/XTLS/Xray-core) |
| 💡 **Credit metode** | [dharak36/xray-onering](https://github.com/dharak36/xray-onering) |
| 📦 **Base default** | Xray-core `v26.6.22` |
| 📄 **Lisensi kit** | MIT |

</div>

---

## ⬇️ Download Prebuilt Binary

**👉 https://github.com/jhopan/xray-onering/releases**

| File | OS | Perangkat |
|---|---|---|
| `xray.linux.arm64.onering` | Linux ARM64 | OpenWrt / STB / Raspberry Pi / VPS ARM |
| `xray.linux.amd64.onering` | Linux x64 | VPS / server / desktop Linux |
| `xray.linux.armv7.onering` | Linux ARMv7 | OpenWrt 32-bit / router lama |
| `xray.windows.amd64.onering.exe` | Windows x64 | Desktop / laptop Windows |
| `xray.windows.arm64.onering.exe` | Windows ARM64 | Surface Pro X / Snapdragon PC |
| `SHA256SUMS.txt` | — | verifikasi integritas |

```bash
# verifikasi checksum
sha256sum -c SHA256SUMS.txt
```

---

## 🔬 Cara Kerja OneRing

```
Config:  serverName = "onering:neva.jhopanstore.my.id:support.zoom.us"
                                 ┌─────────────┘         └──────────────┐
                                 │ real domain                bug domain │
                                 ▼                                       ▼
         TLS SNI ──────► neva.jhopanstore.my.id    TCP ──────► support.zoom.us IP
```

**Alur data:**
1. DNS resolve `support.zoom.us` → IP CDN publik (Zoom, Cloudflare, dll)
2. TCP connect ke IP CDN:443
3. TLS ClientHello SNI = `neva.jhopanstore.my.id` ← **override oleh patch**
4. Server kamu menerima koneksi dengan SNI benar
5. Payload VLESS/VMess/dll berjalan normal

**Patch:** hanya `transport/internet/tls/config.go` → fungsi `parseServerName()` (+28 baris).  
Satu titik, cover **semua protocol** Xray (VLESS, VMess, Trojan, XHTTP, dll).

---

## 📦 Isi Repo

```
xray-onering/
├── onering.patch   ← patch (+28 baris, 1 file, engine Xray)
├── apply.sh        ← pilih versi → clone Xray → apply patch (idempotent)
├── build.sh        ← --ver VER → apply + build binary multi-platform
├── verify.sh       ← cek patch / tree / binary
├── LICENSE         ← MIT © JhopanStore
└── README.md

# setelah build (gitignored):
Xray-core/          ← source tree yang diunduh + dipatch
dist/               ← binary output
```

---

## 🛠️ Build dari Source

### Syarat

| Syarat | Info |
|---|---|
| Go 1.24+ | cek: `go version` |
| Git | untuk clone Xray base |
| Internet | saat pertama `apply.sh` |
| Windows | gunakan Git Bash atau WSL |

### Satu Perintah (Recommended)

```bash
# pilih versi → unduh Xray → apply OneRing → build
bash build.sh --ver v26.6.22 all           # semua platform utama
bash build.sh --ver v26.6.22 linux-arm64   # hanya arm64
bash build.sh -v 26.6.22 windows-amd64    # Windows
bash build.sh --force --ver v26.7.1 all   # paksa re-clone versi baru
```

### Dua Langkah

```bash
bash apply.sh v26.6.22    # unduh + patch
bash build.sh linux-arm64 # compile
```

### Semua Target

| Target | Platform | Gunakan untuk |
|---|---|---|
| `host` | OS sekarang | test lokal |
| `linux-arm64` | Linux ARM64 | OpenWrt / STB / Pi / VPS ARM |
| `linux-amd64` | Linux x64 | VPS / server |
| `linux-arm` | Linux ARMv7 | OpenWrt 32-bit (GOARM=7) |
| `windows-amd64` | Windows x64 | desktop |
| `windows-arm64` | Windows ARM | Surface / Snapdragon |
| `all` | arm64+amd64+win64 | release bundle |
| `custom GOOS GOARCH` | bebas | macOS, FreeBSD, dll |

```bash
bash build.sh custom darwin arm64    # macOS Apple Silicon
bash build.sh custom freebsd amd64   # FreeBSD
```

### Manajemen Versi

```bash
bash apply.sh --list                        # lihat tag Xray terbaru
bash build.sh --force --ver v26.7.1 all    # naik versi
bash verify.sh                              # verifikasi hasil
./dist/xray.linux.amd64.onering version     # cek versi binary
# → Xray 26.6.22 (Xray, Penetrates Everything.)
```

---

## ⚙️ Config Xray

### VLESS + WebSocket + TLS

```json
{
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "support.zoom.us",
        "port": 443,
        "users": [{"id": "UUID-KAMU", "encryption": "none"}]
      }]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "tlsSettings": {
        "serverName": "onering:neva.jhopanstore.my.id:support.zoom.us",
        "fingerprint": "chrome"
      },
      "wsSettings": {
        "path": "/vless",
        "headers": {"Host": "neva.jhopanstore.my.id"}
      }
    }
  }]
}
```

| Field | Isi | Keterangan |
|---|---|---|
| `address` | bug domain | TCP dial target |
| `serverName` | `onering:REAL:BUG` | format OneRing |
| WS `Host` | real domain | header WebSocket |

> ⚠️ Xray v26+: hapus `allowInsecure`. Gunakan `fingerprint: "chrome"` atau `""`.

---

## 🚀 Deploy

### VPS / Server Linux

```bash
scp dist/xray.linux.amd64.onering root@SERVER:/usr/local/bin/xray
ssh root@SERVER 'chmod +x /usr/local/bin/xray && xray version'
# restart service
systemctl restart xray   # atau: marzban / v2ray-agent / dll
```

### OpenWrt ARM64

```bash
scp dist/xray.linux.arm64.onering root@192.168.1.1:/tmp/xray
ssh root@192.168.1.1 '
  cp /usr/bin/xray /usr/bin/xray.bak
  mv /tmp/xray /usr/bin/xray && chmod +x /usr/bin/xray
  xray version
  /etc/init.d/passwall restart
'
```

### OpenWrt ARMv7 (32-bit)

```bash
scp dist/xray.linux.armv7.onering root@ROUTER:/tmp/xray
# lanjut sama seperti arm64
```

### Windows

```bat
dist\xray.windows.amd64.onering.exe run -c config.json
```

---

## 🔄 Update ke Xray Versi Baru

```bash
bash apply.sh --list                       # lihat tag tersedia
bash build.sh --force --ver v26.x.y all   # re-clone + apply + build
bash verify.sh
```

**Jika patch conflict** (Xray ubah `parseServerName`):

```bash
cd Xray-core
git apply --reject ../onering.patch
# edit manual: transport/internet/tls/config.go
# 1) tambah fungsi ParseOneRing()
# 2) di parseServerName() return real domain jika format onering:
git add transport/internet/tls/config.go
git commit -m "OneRing"
git format-patch -1 HEAD --stdout > ../onering.patch
cd .. && bash build.sh all
```

---

## 🤖 CI/CD (GitHub Actions)

```yaml
name: Build OneRing
on:
  push:
    tags: ['onering-*']

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

## 🌐 Ekosistem OneRing

| Repo | Engine | Config key |
|---|---|---|
| **[xray-onering](https://github.com/jhopan/xray-onering)** ← kamu di sini | Xray-core | `serverName` |
| [singbox-onering](https://github.com/jhopan/singbox-onering) | sing-box | `server_name` |
| [clash-onering](https://github.com/jhopan/clash-onering) | Mihomo/Clash | `servername` / `sni` |

---

## 📜 Credits & Lisensi

| | |
|---|---|
| 👨‍💻 Developer kit | **JhopanStore** |
| 💡 Metode OneRing | [dharak36/xray-onering](https://github.com/dharak36/xray-onering) |
| ⚙️ Engine | [XTLS/Xray-core](https://github.com/XTLS/Xray-core) — MPL-2.0 |

**Kit ini** (patch, script, docs): **MIT License** © JhopanStore  
**Binary hasil build**: mengandung Xray-core (MPL-2.0 upstream)
