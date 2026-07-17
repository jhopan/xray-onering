# Apa yang diubah — OneRing

Semua perubahan hanya di **1 file**: `transport/internet/tls/config.go`
Total **+28 baris**. Base: Xray-core `v26.6.22`.

Ringkas: menambah dukungan format SNI `onering:real:bug` supaya bug domain
dipakai untuk koneksi TCP, sementara real domain dikirim sebagai TLS SNI.

---

## 1. Fungsi baru: `ParseOneRing()`

Ditambahkan di dalam `config.go`. Mem-parse string `onering:real:bug`.

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

- Cek prefix `onering:` (huruf besar/kecil bebas)
- Pecah jadi 3 bagian: `onering` : `real` : `bug`
- Kalau format salah / ada bagian kosong → return kosong (fallback aman ke perilaku Xray normal)

## 2. Modifikasi fungsi: `parseServerName()`

Tambah blok cek OneRing sebelum `return c.ServerName`.

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

- Kalau `serverName` = format OneRing → **TLS SNI = real domain**
- **bug domain** tetap dipakai untuk koneksi TCP (diambil dari `address` / `wsSettings.host`)
- WebSocket `Host` otomatis ikut real domain
- Kalau bukan format OneRing → jalan normal seperti Xray asli

---

## Diff mentah

Lihat file `onering.patch` (format `git format-patch`) untuk diff persisnya.
Terapkan ke Xray-core v26.6.22 dengan:

```bash
git clone --depth 1 --branch v26.6.22 https://github.com/XTLS/Xray-core.git
cd Xray-core
git apply ../onering.patch
```

Atau langsung timpa file `transport/internet/tls/config.go` dengan `config.go` di repo ini.
