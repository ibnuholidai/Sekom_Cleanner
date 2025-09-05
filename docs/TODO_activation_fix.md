# TODO - Perbaikan Cek Windows Activation

Tujuan: Membuat fungsi cek aktivasi Windows lebih tahan terhadap perbedaan bahasa (lokalisasi), arsitektur (32/64-bit), serta kebijakan sistem/AV yang bisa memblokir cscript/slmgr. UI tidak diubah.

Langkah Kerja:
- [ ] Perkuat eksekusi slmgr:
  - Gunakan kandidat path untuk cscript:
    - %WINDIR%\System32\cscript.exe
    - %WINDIR%\Sysnative\cscript.exe
    - cscript (fallback)
  - Gunakan kandidat path untuk slmgr.vbs:
    - %WINDIR%\System32\slmgr.vbs
    - %WINDIR%\Sysnative\slmgr.vbs
    - %WINDIR%\SysWOW64\slmgr.vbs
  - Coba kombinasi kandidat hingga berhasil (timeout ketat).
- [ ] Perluas parsing output agar tahan lokalisasi (EN + ID):
  - “permanently activated”, “aktif permanen”, “diaktifkan secara permanen”
  - “will expire”, “activated until”, “grace”, “akan berakhir”, “kedaluwarsa”, “masa tenggang”, “diaktifkan sampai”
- [ ] Tambahkan fallback cepat (timeout <= 5 dtk) via PowerShell CIM:
  - (Get-CimInstance SoftwareLicensingProduct | where { $_.PartialProductKey -and $_.LicenseStatus -eq 1 } | select -First 1).LicenseStatus
  - Jika 1 → anggap Activated; jika gagal/timeout → abaikan (jangan blok UI).
- [ ] Pertahankan parsing informasi /dlv (edition/description/partial key) secara best-effort, tanpa error jika label tidak ditemukan.
- [ ] Bila semua gagal (slmgr diblok/tidak ada output), kembalikan status “⏳ Ditunda (akan diperbarui)” agar UI tetap responsif.
- [ ] Uji manual:
  - Buka tab System Cleaner → Check All
  - Coba “Cek Ulang Aktivasi”
  - Verifikasi status tidak lagi error terus-menerus pada sistem berbahasa Indonesia/berbeda arsitektur.

Catatan:
- Perubahan hanya pada lib/services/system_service.dart → fungsi checkWindowsActivation().
- Tidak mengubah UI atau file lain.
