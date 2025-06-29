# OCR Simple - Tesseract Edition

Aplikasi OCR (Optical Character Recognition) berbasis web berkinerja tinggi yang didukung oleh **Tesseract OCR**. Aplikasi ini menyediakan antarmuka yang bersih untuk ekstraksi teks dari gambar dengan akurasi yang dapat diandalkan dan pengaturan yang mudah.

## 📑 Daftar Isi

- [🚀 Fitur Utama](#-fitur-utama)
- [📋 Persyaratan Sistem](#-persyaratan-sistem)
  - [Instalasi Tesseract OCR](#instalasi-tesseract-ocr)
  - [Verifikasi Instalasi](#verifikasi-instalasi)
- [🛠️ Panduan Memulai](#️-panduan-memulai)
- [🎯 Cara Penggunaan](#-cara-penggunaan)
- [🔧 Konfigurasi Port](#-konfigurasi-port)
- [🌍 Dukungan Bahasa](#-dukungan-bahasa)
- [🚨 Pemecahan Masalah](#-pemecahan-masalah)
- [📊 Tips Performa](#-tips-performa)
- [🔧 Detail Teknis](#-detail-teknis)
- [🌍 Build Cross-Platform](#-build-cross-platform)
  - [Build Platform Cepat](#build-platform-cepat)
  - [Platform & Arsitektur yang Didukung](#platform--arsitektur-yang-didukung)
  - [Distribution Packages](#distribution-packages)
  - [Cross-Compilation Setup](#cross-compilation-setup)
  - [Complete Release Process](#complete-release-process)
  - [Build Management](#build-management)
  - [Environment-Specific Builds](#environment-specific-builds)
- [📦 Dependensi](#-dependensi)
  - [Instalasi Dependensi](#instalasi-dependensi)
- [🛠️ Pengembangan](#️-pengembangan)
  - [Struktur Proyek](#struktur-proyek)
  - [Build Dependencies](#build-dependencies)
  - [Perintah Pengembangan](#perintah-pengembangan)
- [🆚 Why Tesseract over PaddleOCR?](#-why-tesseract-over-paddleocr)
- [🤝 Kontribusi](#-kontribusi)
- [📄 Lisensi](#-lisensi)
- [📞 Dukungan](#-dukungan)
- [🔄 Changelog](#-changelog)

## 🚀 Fitur Utama

- **Mesin OCR Tesseract**: Pengenalan teks open-source standar industri
- **Dukungan Multi-bahasa**: Bahasa Indonesia, Inggris, Mandarin, Jepang, dan 100+ bahasa lainnya
- **Instalasi Mudah**: Pengaturan sederhana menggunakan package manager (brew, apt, dnf)
- **Drag & Drop**: Upload gambar mudah dengan dukungan drag-and-drop
- **Clipboard Paste**: Tempel gambar langsung dari clipboard (Ctrl+V)
- **Pemrosesan Real-time**: Hasil OCR instan dengan performa yang dioptimalkan
- **Antarmuka Modern**: Interface yang bersih dan responsif dengan preview real-time
- **Cross-platform**: Berjalan di macOS, Linux, dan Windows
- **Smart Port Selection**: Otomatis memilih port yang tersedia (9000, 8000, atau 7000)

## 📋 Persyaratan Sistem

### Instalasi Tesseract OCR

Pilih metode instalasi sesuai dengan sistem operasi Anda:

#### 🍎 macOS (Homebrew)
```bash
# Instalasi dasar
brew install tesseract

# Dengan paket bahasa tambahan
brew install tesseract tesseract-lang
```

#### 🐧 Linux (Ubuntu/Debian)
```bash
# Perbarui daftar paket dan install
sudo apt update
sudo apt install tesseract-ocr

# Opsional: Install bahasa tambahan
sudo apt install tesseract-ocr-ind tesseract-ocr-eng
```

#### 🐧 Linux (CentOS/RHEL/Fedora)
```bash
# Untuk sistem yang lebih baru
sudo dnf install tesseract

# Untuk versi lama
sudo yum install tesseract
```

#### 🪟 Windows
1. Unduh dari: https://github.com/UB-Mannheim/tesseract/wiki
2. Jalankan installer sebagai Administrator
3. **Penting**: Centang "Add to PATH" saat instalasi
4. Restart command prompt setelah instalasi

### Verifikasi Instalasi
```bash
tesseract --version
```
Anda akan melihat informasi versi jika Tesseract telah terinstal dengan benar.

## 🛠️ Panduan Memulai

1. **Clone atau unduh proyek ini**
2. **Install Tesseract** (lihat persyaratan sistem di atas)
3. **Jalankan aplikasi:**

```bash
# Build dan jalankan
go build -o ocr-app
./ocr-app

# Atau jalankan langsung
go run main.go
```

4. **Buka browser** ke alamat yang ditampilkan (port 9000, 8000, atau 7000)
5. **Upload gambar** dan saksikan keajaibannya! ✨

## 🎯 Cara Penggunaan

1. **Upload Gambar**: 
   - Drag & drop file
   - Klik tombol "Browse"
   - Paste dari clipboard (Ctrl+V)

2. **Format yang Didukung**: PNG, JPG, JPEG, GIF, BMP, TIFF

3. **Dapatkan Hasil**: Teks muncul secara instan di panel kanan

4. **Salin Teks**: Gunakan tombol "Copy Text" untuk menyalin dengan mudah

## 🔧 Konfigurasi Port

Aplikasi ini secara otomatis akan mencoba port dalam urutan berikut:
- **Port 9000** (prioritas pertama)
- **Port 8000** (jika 9000 tidak tersedia)
- **Port 7000** (jika 8000 tidak tersedia)

Jika semua port sedang digunakan, aplikasi akan menampilkan pesan error.

## 🌍 Dukungan Bahasa

Tesseract mendukung 100+ bahasa. Install paket bahasa tambahan:

- **Bahasa Indonesia**: `tesseract-ocr-ind`
- **Mandarin Sederhana**: `tesseract-ocr-chi-sim`
- **Mandarin Tradisional**: `tesseract-ocr-chi-tra`
- **Bahasa Jepang**: `tesseract-ocr-jpn`
- **Bahasa Korea**: `tesseract-ocr-kor`
- **Bahasa Arab**: `tesseract-ocr-ara`
- **Dan banyak lagi...**

## 🚨 Pemecahan Masalah

### ❌ "tesseract: command not found"
- Pastikan Tesseract telah terinstal
- Periksa apakah sudah ditambahkan ke system PATH
- Restart terminal/command prompt Anda
- Di Windows, pastikan "Add to PATH" dicentang saat instalasi

### ❌ Aplikasi berjalan tapi menampilkan "Not Configured"
- Verifikasi instalasi Tesseract: `tesseract --version`
- Kunjungi halaman `/setup` untuk petunjuk detail
- Periksa log server untuk pesan error

### ❌ Akurasi OCR rendah
- Gunakan gambar beresolusi tinggi dan jelas
- Pastikan kontras yang baik antara teks dan latar belakang
- Coba format PNG untuk hasil terbaik
- Install paket bahasa yang sesuai

### ❌ Port sudah digunakan
- Aplikasi akan otomatis mencoba port alternatif (9000 → 8000 → 7000)
- Jika semua port digunakan, tutup aplikasi lain yang menggunakan port tersebut
- Atau tunggu hingga port tersedia

## 📊 Tips Performa

- **Kualitas Gambar**: Resolusi tinggi = akurasi lebih baik
- **Kontras**: Teks hitam pada latar belakang putih bekerja optimal
- **Format File**: PNG umumnya memberikan hasil terbaik
- **Ukuran File**: Jaga di bawah 5MB untuk performa optimal
- **Pencahayaan**: Pastikan gambar memiliki pencahayaan yang cukup
- **Orientasi**: Pastikan teks dalam orientasi yang benar (tidak terbalik)

## 🔧 Detail Teknis

- **Backend**: Go dengan wrapper `github.com/tiagomelo/go-ocr`
- **Mesin OCR**: Tesseract 4.x atau 5.x
- **Antarmuka Web**: HTML5 modern dengan drag-and-drop
- **Pemrosesan Gambar**: Pemrosesan in-memory dengan file sementara
- **Concurrency**: Pemrosesan OCR thread-safe dengan worker pools
- **Performa**: Dioptimalkan dengan caching, buffer pooling, dan pemrosesan concurrent
- **Port Management**: Sistem pemilihan port otomatis dengan fallback
- **Error Handling**: Penanganan error yang komprehensif dengan logging detail

## 🌍 Build Cross-Platform

Aplikasi ini dapat di-build untuk berbagai sistem operasi dan arsitektur menggunakan Makefile yang komprehensif.

### Build Platform Cepat

```bash
# Build untuk Windows (64-bit)
make build-windows

# Build untuk macOS (Intel)
make build-macos

# Build untuk macOS (Apple Silicon)
make build-macos-arm64

# Build untuk Linux (64-bit)
make build-linux

# Build untuk semua platform sekaligus
make build-cross-platform
```

### Platform & Arsitektur yang Didukung

| Platform | Arsitektur | Perintah | File Output |
|----------|------------|----------|-------------|
| **Windows** | x64 (amd64) | `make build-windows` | `./build/windows/amd64/ocr-app.exe` |
| **Windows** | x86 (386) | `make build-windows-386` | `./build/windows/386/ocr-app.exe` |
| **macOS** | Intel (amd64) | `make build-macos` | `./build/darwin/amd64/ocr-app` |
| **macOS** | Apple Silicon (arm64) | `make build-macos-arm64` | `./build/darwin/arm64/ocr-app` |
| **Linux** | x64 (amd64) | `make build-linux` | `./build/linux/amd64/ocr-app` |
| **Linux** | x86 (386) | `make build-linux-386` | `./build/linux/386/ocr-app` |
| **Linux** | ARM64 | `make build-linux-arm64` | `./build/linux/arm64/ocr-app` |
| **Linux** | ARM | `make build-linux-arm` | `./build/linux/arm/ocr-app` |

### Distribution Packages

Create ready-to-distribute packages:

```bash
# Create packages for all platforms
make package-all

# Create platform-specific packages
make package-windows    # Creates ZIP files
make package-macos      # Creates TAR.GZ files  
make package-linux      # Creates TAR.GZ files
```

Package locations:
- **Windows**: `./build/dist/windows/ocr-app-{version}-windows-{arch}.zip`
- **macOS**: `./build/dist/macos/ocr-app-{version}-darwin-{arch}.tar.gz`
- **Linux**: `./build/dist/linux/ocr-app-{version}-linux-{arch}.tar.gz`

### Cross-Compilation Setup

For cross-compilation (especially Windows builds from macOS/Linux):

```bash
# Install cross-compilation tools
make install-cross-tools

# On macOS via Homebrew
brew install mingw-w64

# On Ubuntu/Debian
sudo apt-get install gcc-mingw-w64

# On CentOS/RHEL/Fedora
sudo dnf install mingw64-gcc mingw32-gcc
```

### Complete Release Process

```bash
# One command to rule them all
make release

# This will:
# 1. Clean previous builds
# 2. Build for all platforms
# 3. Create distribution packages
# 4. Show release summary
```

### Build Management

```bash
# List all available builds
make list-builds

# List all distribution packages
make list-packages

# Get build information
make info

# Clean all builds
make clean
```

### Environment-Specific Builds

```bash
# Development build (with debug symbols)
make build-dev

# Staging build (optimized)
make build-staging

# Production build (fully optimized)
make build-prod
```

## 📦 Dependensi

Proyek ini menggunakan Go modules untuk manajemen dependensi. Dependensi utama meliputi:

- **github.com/tiagomelo/go-ocr**: Wrapper OCR untuk Tesseract
- **Standard Go libraries**: net/http, html/template, net, strconv, dll.

### Instalasi Dependensi

```bash
# Download dan install semua dependensi
go mod download

# Verifikasi dependensi
go mod verify

# Bersihkan dependensi yang tidak digunakan
go mod tidy
```

## 🛠️ Pengembangan

### Struktur Proyek

```
ocr-app/
├── main.go          # File aplikasi utama
├── go.mod           # Definisi Go module
├── go.sum           # Checksum dependensi
├── Makefile         # Otomasi build
├── README.md        # Dokumentasi ini
└── build/           # Direktori output build (dibuat saat build)
    ├── windows/
    ├── darwin/
    └── linux/
```

### Build Dependencies

- **Go 1.21+**: Required for building
- **Make**: For cross-platform build system
- **Tesseract**: OCR engine (runtime dependency)
- **CGO**: Required for Tesseract integration
- **Cross-compilation tools**: For building Windows binaries on non-Windows systems

## 🆚 Why Tesseract over PaddleOCR?

- ✅ **Easier Setup**: Available in package managers
- ✅ **Mature & Stable**: 30+ years of development
- ✅ **Wide Language Support**: 100+ languages built-in
- ✅ **Lower Resource Usage**: Minimal system requirements
- ✅ **Better Documentation**: Extensive community support
- ✅ **Open Source**: Free and always will be

### Perintah Pengembangan

```bash
# Jalankan dalam mode pengembangan
go run main.go

# Build untuk platform saat ini
go build -o ocr-app main.go

# Jalankan test (jika ada)
go test ./...

# Format kode
go fmt ./...

# Periksa kode untuk masalah
go vet ./...

# Bersihkan artifact build
make clean
```

## 🤝 Kontribusi

1. Fork repository ini
2. Buat branch fitur Anda (`git checkout -b feature/fitur-menakjubkan`)
3. Commit perubahan Anda (`git commit -m 'Tambah fitur menakjubkan'`)
4. Push ke branch (`git push origin feature/fitur-menakjubkan`)
5. Buka Pull Request

## 📄 Lisensi

Proyek ini adalah open source dan tersedia di bawah [MIT License](LICENSE).

---

## 📞 Dukungan

Jika Anda mengalami masalah atau memiliki pertanyaan:

1. Periksa bagian [Troubleshooting](#-troubleshooting) di atas
2. Buka issue di repository GitHub
3. Pastikan Tesseract OCR terinstall dengan benar
4. Periksa log aplikasi untuk detail error

## 🔄 Changelog

### v1.1.0
- ✨ Tambah fitur Smart Port Selection (9000, 8000, 7000)
- 🔧 Perbaikan penanganan port yang sudah digunakan
- 📚 Dokumentasi lengkap dalam Bahasa Indonesia
- 🚀 Optimasi performa dan error handling

### v1.0.0
- 🎉 Rilis awal aplikasi OCR
- 🖼️ Dukungan upload gambar dengan drag-and-drop
- 🌐 Antarmuka web yang responsif
- 🔧 Konfigurasi Tesseract OCR

---

**Dibuat dengan ❤️ untuk komunitas OCR**

*Selamat mengekstrak teks! 🚀*