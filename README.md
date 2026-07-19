# OneRing Core (JhopanStore)

Build **Xray-core** dengan patch SNI OneRing: `onering:REAL:BUG`.

- TCP / address → bug domain  
- TLS SNI → real domain  
- Kit: patch + script saja. Bukan app, bukan AAR.

| | |
|---|---|
| **Developer** | **JhopanStore** |
| **Repo** | https://github.com/jhopan/jhopanstore-onering |
| **Default base** | Xray-core `v26.6.22` (bisa diganti) |
| **License (kit ini)** | MIT |

---

## Isi repo (bersih)

```
jhopanstore-onering/
├── onering.patch   # patch OneRing (+28 baris)
├── apply.sh        # pilih versi → clone → apply
├── build.sh        # --ver → apply + build multi platform
├── verify.sh       # cek patch / binary
├── LICENSE         # MIT
└── README.md
```

Setelah build (lokal, gitignored):

```
Xray-core/   # tree Xray yang diunduh + dipatch
dist/        # binary
```

---

## Release (prebuilt)

Unduh binary siap pakai:

**https://github.com/jhopan/jhopanstore-onering/releases**

Tag contoh: `onering-v1.0-xray-v26.6.22`

| Asset | Platform |
|---|---|
| `xray.linux.arm64.onering` | OpenWrt / STB / Pi |
| `xray.linux.amd64.onering` | VPS / Linux |
| `xray.windows.amd64.onering.exe` | Windows x64 |
| `SHA256SUMS.txt` | checksum |

---

## Syarat build dari source

- Go 1.24+  
- Git  
- Internet  
- Windows: Git Bash / WSL (jalankan `.sh`)

---

## Build (pilih versi → unduh → apply → binary)

### Satu perintah

```bash
bash build.sh --ver v26.6.22 linux-arm64
bash build.sh -v 26.6.22 all
bash build.sh --force --ver v26.7.1 windows-amd64
```

### Dua langkah

```bash
bash apply.sh v26.6.22
bash build.sh linux-arm64

bash apply.sh --list          # list tag Xray
bash apply.sh --force v26.6.22
```

Tanpa argumen versi → default `v26.6.22`.

### Target

| Target | Hasil |
|---|---|
| `host` | OS sekarang |
| `linux-arm64` | OpenWrt / STB / Pi |
| `linux-amd64` | VPS / Linux |
| `linux-arm` | OpenWrt 32-bit (GOARM=7) |
| `windows-amd64` | Windows x64 |
| `windows-arm64` | Windows ARM |
| `all` | linux arm64 + amd64 + windows amd64 |
| `custom goos goarch` | bebas |

Output: `dist/xray.<os>.<arch>.onering[.exe]`

```bash
bash verify.sh
./dist/xray.linux.amd64.onering version
```

---

## Config SNI

```json
"tlsSettings": {
  "serverName": "onering:REAL_DOMAIN:BUG_DOMAIN",
  "fingerprint": ""
}
```

| Layer | Value |
|---|---|
| TCP / `address` | bug domain |
| TLS SNI | real domain (dari OneRing) |
| WS Host | real domain (biasanya) |

Xray v26+: jangan `allowInsecure`.

---

## Deploy singkat

```bash
# VPS
scp dist/xray.linux.amd64.onering root@SERVER:/usr/local/bin/xray

# OpenWrt
scp dist/xray.linux.arm64.onering root@ROUTER:/tmp/xray
# backup + ganti /usr/bin/xray + restart passwall

# Windows
dist\xray.windows.amd64.onering.exe run -c config.json
```

---

## Patch gagal di Xray versi baru

```bash
cd Xray-core
git apply --reject ../onering.patch
# edit manual ParseOneRing + parseServerName di transport/internet/tls/config.go
git add transport/internet/tls/config.go && git commit -m "OneRing"
git format-patch -1 HEAD --stdout > ../onering.patch
cd .. && bash build.sh all
```

---

## Credits / Source

| | |
|---|---|
| **Pengembang kit ini** | **JhopanStore** |
| **Metode / inspirasi OneRing** | [dharak36/xray-onering](https://github.com/dharak36/xray-onering) |
| **Engine base** | [XTLS/Xray-core](https://github.com/XTLS/Xray-core) (MPL-2.0) |

Repo ini **bukan** salinan penuh Xray-core. Hanya patch + script build.  
Binary hasil build tetap mengandung Xray-core (lisensi upstream MPL-2.0).  
Kode kit (script, patch packaging, docs) dilisensikan **MIT** — lihat `LICENSE`.
