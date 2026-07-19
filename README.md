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
| Base | Xray-core `v26.6.22` |
| File | `transport/internet/tls/config.go` |
| License | MPL-2.0 (lihat `NOTICE`) |

---

## Struktur

```
jhopanstore-onering/
├── onering.patch       # patch (git format-patch)
├── config.go           # drop-in full file (opsional)
├── apply.sh            # clone base + apply patch
├── build.sh            # build binary multi-platform
├── verify.sh           # cek patch / binary
├── VERSION
├── CHANGES.md
├── NOTICE
└── README.md
```

Setelah `apply.sh`:

```
Xray-core/              # full tree (gitignored)
dist/                   # binary output
```

Repo ini **tidak** bawa full history Xray. Hanya patch + script + docs.

---

## Syarat

- Go 1.24+ (dev: Go 1.26 OK)
- Git
- Internet (clone base sekali)

---

## Build core

```bash
# 1) ambil Xray base + patch OneRing
bash apply.sh

# 2) build binary
bash build.sh linux-arm64      # OpenWrt / STB / Pi
bash build.sh linux-amd64      # VPS / server
bash build.sh windows-amd64    # Windows
bash build.sh host             # OS ini
bash build.sh all
```

Output: `dist/xray.<os>.<arch>.onering[.exe]`

```bash
bash verify.sh
./dist/xray.linux.amd64.onering version
```

### Custom / env

```bash
bash build.sh custom linux arm GOARM=7
XRX_VER=v26.6.22 bash apply.sh
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

Detail perubahan: `CHANGES.md`. Diff: `onering.patch`.

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

Android AAR / app = packaging terpisah, bukan isi repo ini.

---

## Upgrade base Xray

```bash
XRX_VER=v26.x.y bash apply.sh
# conflict → edit manual, regenerate onering.patch
bash build.sh all
```

---

## License

Xray-core MPL-2.0 (XTLS). Patch OneRing ikut MPL-2.0. Lihat `NOTICE`.
