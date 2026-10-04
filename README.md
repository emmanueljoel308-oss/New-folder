# Wi-Fi Guard

A small Windows desktop utility that adds or removes a Windows WLAN block filter for a selected Wi-Fi network name (SSID).

## Run

1. Open PowerShell in this folder.
2. Run:

   ```powershell
   python .\wifi_guard.py
   ```

3. Accept the Windows administrator prompt.
4. Enter the exact Wi-Fi network name and choose **Block network**.

The app uses Windows `netsh wlan` filters. The filter is managed by Windows and remains active after the app closes. Use **Allow network** to remove the block.

## Build standalone Windows downloads

The standalone release targets 32-bit and 64-bit Windows 7, 8, 10, and 11. The 32-bit executable runs on both 32-bit and 64-bit Windows; the 64-bit executable requires 64-bit Windows. Windows 7 must be fully updated (including SP1 and required platform updates).

To build both executables, use 64-bit Windows with Python 3.8 installed in both architectures. Python 3.8 is the last Python release line that supports Windows 7. Install the pinned build dependency into each interpreter:

```powershell
& "$env:LOCALAPPDATA\Programs\Python\Python38-x64\python.exe" -m pip install -r .\requirements-build.txt
& "$env:LOCALAPPDATA\Programs\Python\Python38-x86\python.exe" -m pip install -r .\requirements-build.txt
```

Then run:

```powershell
.\build_standalone.ps1
```

The resulting single-file downloads are `dist\windows-x64\Wi-Fi Guard.exe` and `dist\windows-x86\Wi-Fi Guard.exe`. The script also bundles both executables and a buyer guide into `dist\Wi-Fi-Guard-Windows.zip`, ready to upload to a digital-download store. Set `PYTHON_X64` and `PYTHON_X86` if the interpreters are installed in different locations.

To create a 1200×630 Payhip product-cover image, run `.\build_payhip_cover.ps1`. The PNG is saved as `dist\Wi-Fi-Guard-Payhip-Cover.png`.

To render vertical, square, and widescreen narrated promo videos, install FFmpeg with `ffmpeg` and `ffprobe` available on `PATH`, then run `.\build_social_videos.ps1`. The H.264/AAC MP4s and ready-to-post caption are placed in `dist\Wi-Fi-Guard-Social-Video`, with a distributable ZIP at `dist\Wi-Fi-Guard-Social-Videos.zip`. The script uses the installed Windows `Microsoft Zira Desktop` speech voice.

This legacy-compatible build uses the end-of-life Python 3.8 runtime inside the executables. These builds were produced on Windows 10; test on each advertised Windows version before distributing. Keep the app limited to its current local Wi-Fi-filter functionality and rebuild/test if you add dependencies.

## Build a Windows installer

On 64-bit Windows, install Python and Inno Setup 6, then install PyInstaller:

```powershell
python -m pip install pyinstaller
```

Run the build script from PowerShell:

```powershell
.\build_installer.ps1
```

The setup program is written to `dist\installer\WiFiGuardSetup.exe`. It installs the app under Program Files, adds a Start Menu shortcut, and offers an optional desktop shortcut. The installed app asks for administrator permission when it starts.

## Notes

- This affects only the Windows PC where the app is run.
- Administrator permission is required.
- The SSID must match the network name exactly.
- Existing Wi-Fi connections may need to be disconnected manually before the block takes effect for that connection.
