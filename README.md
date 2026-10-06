# AI Setup (Claude 3P & 9Router)

Script instalasi otomatis untuk menyiapkan **Claude Desktop (Mode 3P)** dan gateway **9Router** di Windows.

## Cara Menggunakan (Pilih Salah Satu)

### Opsi 1: One-Liner PowerShell (Paling Direkomendasikan & Bebas Blokir)
1. Buka Start Menu, ketik **PowerShell**, lalu klik kanan **Run as administrator**.
2. Salin dan jalankan perintah berikut:
   ```powershell
   irm https://raw.githubusercontent.com/Vidlyzer/ai-setup/main/setup.ps1 | iex
   ```
3. Saat browser terbuka, klik tombol **`+ Add`** lalu login ke akun Google kamu.
4. Kembali ke PowerShell dan tekan tombol **Enter**.

---

### Opsi 2: Download File Batch (`setup_claude3p.bat`)
1. Download file [`setup_claude3p.bat`](./setup_claude3p.bat).
2. Klik kanan file `setup_claude3p.bat` -> **Properties** -> centang **Unblock** -> klik **OK**.
3. Klik kanan lagi -> **Run as administrator**.
4. Ikuti instruksi login di browser, lalu tekan **Enter** di terminal.

---

## Apa Saja yang Diatur Otomatis?
1. **Runtime:** Memasang Node.js LTS, Python 3.12 (lengkap dengan Global PATH permanen), dan aplikasi resmi Claude Desktop dari Anthropic.
2. **Domain Alias:** Menambahkan alias `127.0.0.1 9router` ke file hosts sehingga URL dashboard bersih: `http://9router:20128`.
3. **9Router Service:** Dijalankan hening di latar belakang (*silent background*) dan otomatis aktif setiap kali Windows dinyalakan.
4. **Model Combo:** Membuat combo model `claude-default` dengan strategi **Round Robin** antara:
   - `Gemini 3.8 Flash Medium`
   - `Claude Opus 4.6 (Thinking)`
5. **Claude 3P Sync:** Menghubungkan Claude Desktop langsung ke gateway 9Router secara instan.
