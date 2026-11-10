# Windows build & run

ECE-screen runs on Windows with **Go + MinGW (CGO for raylib) + libmpv DLL + OpenGL**.

The Windows build uses `go build -tags nocgo` so **go-mpv** loads `libmpv.dll` at runtime (no `mpv/client.h` package needed).

## 1. Install tools

1. **Go** — https://go.dev/dl (1.26+)
2. **MSYS2** — https://www.msys2.org  
   In the **MINGW64** shell:

   ```bash
   pacman -S --needed mingw-w64-x86_64-gcc mingw-w64-x86_64-pkgconf mingw-w64-x86_64-ffmpeg
   ```

   Add `C:\msys64\mingw64\bin` to your user **PATH**.

3. **libmpv** — download a Windows `libmpv` build (e.g. from  
   https://sourceforge.net/projects/mpv-player-windows/files/libmpv/ )  
   and put `libmpv-2.dll` (or `libmpv.dll`) in the repo’s `deps\` folder.

## 2. Build & run

From PowerShell in the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\windows\doctor.ps1
powershell -ExecutionPolicy Bypass -File scripts\windows\build.ps1
powershell -ExecutionPolicy Bypass -File scripts\windows\run.ps1
```

Or double-click **`build.bat`** / **`run.bat`**.

Admin UI while running: http://localhost:8090/_/  
Quit with **X**.

## 3. Kiosk autostart

Use `deploy\ece-screen-windows.bat`:

1. Win+R → `shell:startup`
2. Create a shortcut to `deploy\ece-screen-windows.bat`

Or Task Scheduler → At log on → start that bat.

## Notes

- Working directory must contain `pb_data\` (created on first run) and `resources\fonts\twemoji`.
- Optional `.env` (`FPS`, `ZOOM`, …) is loaded by `run.ps1`.
- Video on Windows uses a borderless always-on-top mpv window over the main media card (not Linux-style transparent hole-punch).
