# OneRing for Xray-core

OneRing adalah patch untuk **Xray-core** yang menambahkan kemampuan **SNI override** dengan format `onering:real:bug`.

Dengan OneRing, kamu bisa memakai satu **bug domain** (host gratis / lolos DPI) untuk koneksi TCP, sementara **TLS SNI** yang dikirim adalah **real domain** milikmu — tanpa perlu edit banyak field di config.

- **Base**: Xray-core `v26.6.22`
- **Versi OneRing**: `onering-v1.0`
- **Perubahan**: 1 file, +28 baris (`transport/internet/tls/config.go`)

> Ini repo pengembangan mandiri. Isinya **hanya kode OneRing kita sendiri** (patch + script), bukan salinan penuh Xray-core. Xray-core asli tetap milik XTLS (lihat bagian Lisensi).

---

## Apa yang diubah

Semua perubahan ada di `transport/internet/tls/config.go`:

### 1. Fungsi baru `ParseOneRing()`

Mem-parse format `onering:real:bug`:

```go
// ParseOneRing parses OneRing format: onering:real:bug
// Returns real domain and bug domain, or empty strings if not OneRing format
func ParseOneRing(serverName string) (real, bug string) {
	const prefix = "onering:"

	// Case-insensitive prefix check
	if !strings.HasPrefix(strings.ToLower(serverName), prefix) {
		return "", ""
	}

	// Split by colon: onering:real:bug
	parts := strings.SplitN(serverName, ":", 3)
	if len(parts) != 3 || parts[1] == "" || parts[2] == "" {
		return "", ""
	}

	return strings.TrimSpace(parts[1]), strings.TrimSpace(parts[2])
}
```

- Cek prefix `onering:` (case-insensitive)
- Split jadi 3 bagian: `onering` : `real` : `bug`
- Kalau format salah / ada bagian kosong → return kosong (fallback ke perilaku Xray normal, aman)

### 2. Modifikasi `parseServerName()`

```go
func (c *Config) parseServerName() string {
	if IsFromMitm(c.ServerName) {
		return ""
	}

	// OneRing support: parse format onering:real:bug and use real domain for SNI
	if oneRingReal, oneRingBug := ParseOneRing(c.ServerName); oneRingReal != "" {
		errors.LogDebug(context.Background(),
			"OneRing enabled: using real domain ", oneRingReal,
			" for SNI (bug domain: ", oneRingBug, ")")
		return oneRingReal
	}

	return c.ServerName
}
```

- Kalau `serverName` = format OneRing → **TLS SNI pakai real domain**
- **Bug domain** tetap dipakai untuk koneksi TCP (dari `address` / `wsSettings.host`)
- WebSocket `Host` otomatis ikut real domain
- Kalau bukan format OneRing → jalan normal seperti Xray biasa

**Kompatibel penuh** dengan semua fitur Xray lain (WS, TLS, gRPC, routing, balancer, dst).

---

## Cara pakai di config

Cukup ganti `serverName` di `tlsSettings`:

```json
{
  "streamSettings": {
    "network": "ws",
    "security": "tls",
    "tlsSettings": {
      "serverName": "onering:real.domainku.com:bug.gratisan.com"
    },
    "wsSettings": {
      "path": "/vless",
      "host": "bug.gratisan.com"
    }
  }
}
```

- **TCP connect** → `bug.gratisan.com`
- **TLS SNI** → `real.domainku.com`
- **WS Host** → ikut real domain otomatis

---

## Build

Butuh Go 1.24+ dan koneksi internet (untuk clone Xray-core base).

```bash
# 1. Terapkan patch OneRing ke Xray-core v26.6.22
bash apply.sh

# 2. Build binary OneRing
bash build.sh
```

Hasil build ada di folder `Xray-core/`:

- `xray.linux.arm64.onering`  — router / STB (OpenWrt, Passwall)
- `xray.linux.amd64.onering`  — Linux x86_64 / WSL
- `xray.windows.amd64.onering.exe` — Windows

Verifikasi:

```bash
./Xray-core/xray version
# Xray 26.6.22 ... (base) + OneRing SNI override
```

---

## Struktur repo

```
onering-xray-core/
├── README.md          # dokumentasi ini
├── onering.patch      # patch OneRing (git format-patch, +28 baris)
├── apply.sh           # clone Xray v26.6.22 + apply patch
├── build.sh           # build binary multi-arch
└── NOTICE             # atribusi lisensi Xray-core (MPL-2.0)
```

---

## Roadmap

- [x] `onering-v1.0` — SNI override (`onering:real:bug`)
- [ ] Limit per-IP
- [ ] Limit per-GB (kuota)
- [ ] Traffic split khusus game

---

## Lisensi

Xray-core dilisensikan **MPL-2.0** oleh [XTLS](https://github.com/XTLS/Xray-core).
Patch OneRing ini adalah modifikasi di atas Xray-core `v26.6.22` dan mengikuti lisensi yang sama.
Lihat file `NOTICE`.
