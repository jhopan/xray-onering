# OneRing for Xray-core

Repo resmi: https://github.com/jhopan/jhopanstore-onering

Patch **Xray-core** supaya `serverName` bisa:

```
onering:REAL_DOMAIN:BUG_DOMAIN
```

- TCP dial → bug domain (atau address config)
- TLS SNI → real domain
- 1 file, +28 baris
- **Bukan app. Bukan AAR.** Binary/core saja — dipakai di mana saja.

| Field | Value |
|---|---|
| OneRing | `onering-v1.0` |
| Base default | Xray-core `v26.6.22` (bisa diganti) |
| File | `transport/internet/tls/config.go` |
| License | MPL-2.0 (lihat `NOTICE`) |

---

## Struktur

```
jhopanstore-onering/
├── onering.patch       # patch (git format-patch)
├── config.go           # drop-in full file (opsional)
├── apply.sh            # pilih versi → clone → apply
├── build.sh            # --ver VER → apply + build
├── verify.sh
├── VERSION
├── CHANGES.md
├── NOTICE
└── README.md
```

Setelah apply/build:

```
Xray-core/              # full tree (gitignored)
dist/                   # binary output
```

---

## Syarat

- Go 1.24+ (dev: Go 1.26 OK)
- Git
- Internet (clone base)

---

## Cara pakai (pilih versi → unduh → apply → build)

### Satu perintah (disarankan)

```bash
# pilih versi Xray → clone/unduh → apply OneRing → build
bash build.sh --ver v26.6.22 linux-arm64
bash build.sh -v 26.6.22 all
bash build.sh --force --ver v26.7.1 windows-amd64
```

### Dua langkah

```bash
bash apply.sh v26.6.22          # unduh tag + apply OneRing
bash build.sh linux-arm64       # compile

# list tag Xray terbaru
bash apply.sh --list

# paksa re-clone
bash apply.sh --force v26.6.22
```

Default versi (kalau arg kosong): isi `VERSION` (`base=xray-core v...`) atau `v26.6.22`.

Env alternatif:

```bash
XRX_VER=v26.6.22 bash apply.sh
```

---

## Target build

| Target | Hasil |
|---|---|
| `host` | OS sekarang |
| `linux-arm64` | OpenWrt / STB / Pi |
| `linux-amd64` | VPS / desktop Linux |
| `linux-arm` | OpenWrt 32-bit (GOARM=7) |
| `windows-amd64` | Desktop Windows |
| `windows-arm64` | Windows ARM |
| `all` | arm64+amd64 linux + win amd64 |
| `custom goos goarch` | bebas |

Output: `dist/xray.<os>.<arch>.onering[.exe]`

```bash
bash verify.sh
./dist/xray.linux.amd64.onering version
```

---

## Config

```json
"tlsSettings": {
  "serverName": "onering:neva.jhopanstore.my.id:support.zoom.us",
  "fingerprint": ""
}
```

| Layer | Value |
|---|---|
| TCP / address | bug domain |
| TLS SNI | real domain |
| WS Host | real domain (biasanya) |

Xray v26+: jangan `allowInsecure`. Pakai `fingerprint: ""`.

Detail: `CHANGES.md`. Diff: `onering.patch`.

---

## Deploy singkat

**VPS**
```bash
scp dist/xray.linux.amd64.onering root@SERVER:/usr/local/bin/xray
```

**OpenWrt**
```bash
scp dist/xray.linux.arm64.onering root@ROUTER:/tmp/xray
# backup + ganti /usr/bin/xray + passwall restart
```

**Windows**
```text
dist\xray.windows.amd64.onering.exe run -c config.json
```

Android AAR = packaging terpisah (`libxray-mobile`), bukan isi repo ini.

---

## Kalau patch gagal di versi baru

Upstream ubah `parseServerName` → `git apply` error.

```bash
cd Xray-core
git apply --reject ../onering.patch
# edit manual ParseOneRing + parseServerName (lihat CHANGES.md)
git add transport/internet/tls/config.go
git commit -m "OneRing"
git format-patch -1 HEAD --stdout > ../onering.patch
# update VERSION base=...
cd ..
bash build.sh all
```

---

## License

Xray-core MPL-2.0 (XTLS). Patch OneRing ikut MPL-2.0. Lihat `NOTICE`.
