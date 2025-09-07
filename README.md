<<<<<<< HEAD
=======
<img width="1920" height="1036" alt="Image" src="https://github.com/user-attachments/assets/40a6339c-44d8-471f-8a74-2d1d3f46c1e0" />

<img width="1920" height="1041" alt="Image" src="https://github.com/user-attachments/assets/ee551d38-6056-454b-90cb-a2d55951a1dc" />

<img width="1920" height="1042" alt="Image" src="https://github.com/user-attachments/assets/2cbc3b86-1cf0-4f57-933c-61c859aa0b16" />

<img width="1920" height="1047" alt="Image" src="https://github.com/user-attachments/assets/a6d0f07b-0152-40db-8cb2-01a970a4a2ea" />

<img width="1920" height="1036" alt="Image" src="https://github.com/user-attachments/assets/8fe78f9f-60c6-4322-99a1-4a3286a04e0d" />

<img width="1920" height="1032" alt="Image" src="https://github.com/user-attachments/assets/3c940235-8bc5-4188-9e2c-b05900117612" />

# Sekom Cleaner (sekom_clenner)
>>>>>>> 542eebb5def035174505e2c20e4c7a285cfa8cd5


# Sekom Cleaner (sekom_clenner)
Alat pembersih sistem dan utilitas desktop untuk Windows yang membantu teknisi/administrator membersihkan data browser, folder sistem, jejak recent, serta menyediakan pintasan ke beberapa pengaturan Windows. Aplikasi ini juga menyertakan panel Testing untuk pengujian perangkat (keyboard, audio L/R, layar/RGB), serta helper native untuk beberapa operasi sistem.

## Fitur Utama

- System Cleaner
  - Reset & bersihkan data browser: Google Chrome, Microsoft Edge, Mozilla Firefox
  - Bersihkan folder sistem: Documents, Downloads, Music, Pictures, Videos, dan 3D Objects
  - Hapus Recent Files (Start/Search, Quick Access, Office) dan unpin Microsoft Photos dari Start
  - Kosongkan Recycle Bin
- Windows System Tools
  - Cek & update Windows Defender
  - Jalankan Windows Update
  - Periksa driver
  - Cek ulang status aktivasi Windows dan Office
  - Buka PowerShell aktivasi (jalankan perintah eksternal)
  - Buka pengaturan: Windows Update, Windows Security, Device Manager
- Application Manager, Shortcut/Uninstaller
  - Kelola aplikasi dan pintasan (sesuai tab terkait)
- Battery Health
  - Panel baterai (informasi/alat bantu yang relevan)
- Testing
  - Pengujian keyboard (offline web test via WebView2)
  - Tes audio kiri/kanan (L/R)
  - Tes warna layar/RGB

## Peringatan & Disclaimer Penting

- Operasi pembersihan bisa menghapus data secara permanen. Lakukan backup terlebih dahulu dan gunakan dengan hati-hati.
- Beberapa fitur (misalnya membuka PowerShell untuk menjalankan skrip aktivasi eksternal) mungkin memerlukan hak Administrator dan tunduk pada aturan hukum/lisensi perangkat lunak Anda. Gunakan hanya pada perangkat yang Anda miliki atau yang secara hukum Anda berhak kelola. Pengguna bertanggung jawab penuh atas konsekuensi penggunaan fitur tersebut.
- Beberapa fungsi pembersihan dapat menghentikan proses aplikasi (mis. menutup browser) agar proses reset/bersih berjalan tuntas.
- Jalankan aplikasi sebagai Administrator untuk menghindari kegagalan karena izin (permission).

## Persyaratan Sistem (Development)

- OS: Windows 10/11 (x64)
- Flutter SDK: 3.x dengan Dart SDK ^3.8.1 (lihat `environment` pada pubspec.yaml)
- Microsoft Edge WebView2 Runtime (wajib untuk fitur WebView):  
  https://developer.microsoft.com/en-us/microsoft-edge/webview2/
- Toolchain Flutter Desktop Windows (Visual Studio dengan komponen Desktop development with C++)
- (Opsional, tergantung publish helper) .NET 7 Runtime jika diperlukan oleh `native/publish/SekomHelper.exe`

Untuk pengguna akhir (bila aplikasi sudah dibundel), cukup Windows 10/11 dan WebView2 Runtime terpasang.

## Dependensi Utama

- window_manager: kontrol jendela native desktop
- webview_windows: embed WebView2 (untuk Testing)
- just_audio, just_audio_windows dan audioplayers: audio playback (termasuk pan L/R)
- url_launcher: buka URL / pengaturan sistem
- process_run: eksekusi perintah shell/PowerShell
- path, path_provider, file_picker: utilitas file dan path

Lihat detail versi pada `pubspec.yaml`.

## Instalasi (Development)

1. Clone repository
   ```bash
   git clone https://github.com/USERNAME/REPO.git
   cd REPO
   ```
2. Pastikan Flutter Windows desktop aktif
   ```bash
   flutter doctor
   flutter config --enable-windows-desktop
   ```
3. Install dependensi
   ```bash
   flutter pub get
   ```

## Menjalankan Aplikasi (Windows)

- Jalankan mode debug:
  ```bash
  flutter run -d windows
  ```
- Banyak fitur sistem memerlukan hak Administrator. Jika perlu:
  - Buka VSCode/Terminal sebagai Administrator sebelum menjalankan `flutter run`, atau
  - Build release lalu jalankan executable-nya dengan “Run as administrator”.

## Build/Release

- Build Windows (Release):
  ```bash
  flutter build windows --release
  ```
- Output executable biasanya berada di:
  ```
  build/windows/runner/Release/
  ```
- Helper Native:
  - Beberapa fungsi mengandalkan `native/publish/SekomHelper.exe`. Aplikasi mencoba menemukan file ini secara otomatis melalui beberapa lokasi kandidat.
  - Saat distribusi, pastikan `SekomHelper.exe` ikut dipaketkan (misalnya di folder yang sudah dipindai oleh aplikasi). Jika helper gagal dijalankan, Anda mungkin perlu memasang .NET 7 Runtime atau memposisikan file di lokasi yang terdeteksi.

## Struktur Proyek (Ringkas)

- lib/
  - main.dart: bootstrap aplikasi Flutter (MaterialApp, tema, home)
  - screens/
    - main_screen.dart: tab utama (System Cleaner, Application Manager, Shortcut/Uninstaller, Battery Health, Testing)
  - services/
    - system_service.dart: operasi sistem (pembersihan browser/folder, recent files, recycle bin, update defender, windows update, aktivasi, dll.)
  - widgets/: komponen UI (BrowserSection, SystemFoldersSection, WindowsSystemSection, dsb.)
  - data/, models/: data statis dan model status sistem
- assets/: aset umum (termasuk audio)
- lib/keyboard_test/: halaman/web offline untuk pengujian keyboard (dipakai oleh WebView2)
- native/
  - publish/SekomHelper.exe: helper native (C#/.NET) untuk operasi tertentu
- scripts/: skrip tambahan (mis. test_thorough.ps1)
- docs/: catatan TODO/roadmap spesifik
- test/: unit/widget UI test

## Konfigurasi Aset

Di `pubspec.yaml`:
```yaml
flutter:
  uses-material-design: true
  assets:
    - "lib/keyboard_test/"
    - assets/
```
Pastikan struktur direktori sesuai agar WebView/Test dan audio dapat dimuat.

## Cara Menggunakan

1. Buka aplikasi dan pilih tab System Cleaner.
2. Centang item yang ingin dibersihkan:
   - Browser (Chrome/Edge/Firefox), dan opsi Reset ke setelan awal
   - Folder sistem (Documents, Downloads, Music, Pictures, Videos, 3D Objects)
   - Hapus Recent Files dan/atau Kosongkan Recycle Bin
3. Tekan “Check All” untuk pengecekan status umum (Defender, Update, Driver, Aktivasi).
4. Tekan “Bersihkan” untuk menjalankan pembersihan. Ikuti dialog konfirmasi.
5. Gunakan tab lain untuk:
   - Application Manager/Shortcut: kelola aplikasi/pintasan
   - Battery Health: info/alat bantu baterai
   - Testing: Pengujian keyboard, audio L/R, RGB (memerlukan WebView2 Runtime di Windows)

## Troubleshooting

- WebView tidak tampil (panel Testing)
  - Pastikan Microsoft Edge WebView2 Runtime terpasang.
  - Jika tetap gagal, gunakan tombol fallback “Open in Browser” (jika tersedia) untuk membuka laman pengujian di browser eksternal.
- Gagal menjalankan aksi sistem
  - Jalankan aplikasi sebagai Administrator.
  - Nonaktifkan sementara antivirus jika memblokir proses helper/scripting (pastikan Anda tahu risikonya).
- Aktivasi Windows/Office timeout atau tertunda
  - Gunakan tombol “Cek Ulang” atau fitur “Open Activation Shell” untuk memicu ulang proses.
  - Pastikan koneksi internet stabil.
- Audio L/R tidak terdengar
  - Periksa output device, pastikan driver audio berfungsi, dan volume tidak di-mute.

## Pengujian

- Menjalankan test:
  ```bash
  flutter test
  ```
- Tersedia beberapa test dasar di folder `test/` (mis. `ui_test.dart`, `widget_test.dart`, `persistence_test.dart`).

## Roadmap & Catatan

- Lihat `docs/TODO_activation_fix.md` dan `docs/TODO_testing_tab.md` untuk rencana peningkatan lebih lanjut.
- Lihat `TODO.md` untuk item yang sudah/sedang dikerjakan.

## Kontribusi

Kontribusi dipersilakan melalui Pull Request:
- Fork repo dan buat branch fitur/bugfix
- Ikuti gaya penamaan branch
- Jelaskan perubahan dengan jelas pada PR dan sertakan langkah uji bila relevan

## Lisensi

Saat ini: Proprietary (Hak Cipta Pribadi).  
Silakan tambahkan file LICENSE jika Anda ingin menggunakan lisensi open-source (misalnya MIT/Apache-2.0/GPL) dan perbarui bagian ini.

## Kredit

Proyek ini memanfaatkan pustaka pihak ketiga:
- window_manager
- webview_windows
- just_audio, just_audio_windows, audioplayers
- url_launcher
- process_run
- path, path_provider, file_picker

Serta konten pengujian offline (keyboard test) yang dipaketkan di repo ini untuk penggunaan lokal.

---

Catatan Penamaan: Nama paket saat ini adalah `sekom_clenner` namun nama aplikasi ditampilkan sebagai “Sekom Cleaner”. Anda bisa menyesuaikan penamaan paket/repo sesuai preferensi (opsional).
