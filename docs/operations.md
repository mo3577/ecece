# Operations

_Last updated: 2026-11-10_

## Windows

Native Windows build/run (Go + MinGW CGO + libmpv DLL):

| Script | Purpose |
|---|---|
| `scripts/windows/doctor.ps1` | Check Go, gcc, libmpv DLL, ffprobe |
| `scripts/windows/build.ps1` | `go build -o ECE-screen.exe` |
| `scripts/windows/run.ps1` | Load `.env`, ensure PATH, launch |
| `build.bat` / `run.bat` | Double-click wrappers |
| `deploy/ece-screen-windows.bat` | Kiosk / Startup-folder launcher |

Put `libmpv-2.dll` (or `libmpv.dll`) in `deps\`. Details: [`scripts/windows/README.md`](../scripts/windows/README.md).

## Makefile (preferred on Linux/macOS)

`make` shows a menu (TUI helpers in `scripts/tui.sh`; honours `NO_COLOR`). `make build` / `make run` first detect a fresh clone (missing `.build/deps.stamp`, or `go.mod`/`go.sum` newer), run a system-dependency check (`make doctor`) and `go mod download`, then build `./ECE-screen`. `make test` = `go vet` + `gofmt -l` check + `go test ./...`. Also: `setup`, `deps`, `labwc`, `vet`, `fmt`, `clean`, `distclean`.

**Fresh-clone bootstrap (`make build` / `make run` / `make labwc`):** the stamp rule runs `scripts/tui.sh deps` then `doctor` then `go mod download`. On **Arch (pacman)** `deps` installs whatever is missing with `sudo pacman -S --needed --noconfirm`: `go gcc pkgconf mpv ffmpeg libx11 libxrandr libxinerama libxcursor libxi libglvnd labwc xorg-xwayland` (sudo runs on the real terminal so it can ask for a password; `DEPS_DRY_RUN=1` only prints the command). On other distros it lists the missing packages and `doctor` fails on the required ones. The Go modules (raylib-go, go-mpv, PocketBase) come from `go mod download`. Editing `scripts/tui.sh` re-triggers the bootstrap.

**`make labwc`:** builds if needed, then runs `labwc -S ./ECE-screen` — the board is labwc's session command, so quitting the board (press **X**) also ends labwc. Needs `labwc` + `xorg-xwayland` (installed by `deps`) because the raylib window is an X11 client.

## Build / run / lint

```bash
go build ./...   # build
go vet ./...     # lint (clean as of 2026-10-24)
gofmt -l .       # formatting (clean)
go run .         # needs a display + libmpv (cannot run headless)
```

Unit tests exist for `lib/fonts` (`Reshape`), `lib/emoji` (`Split`, nil atlas) and `Parse12HourTime`; nothing renders, so `go test ./...` runs headless. Press **X** to quit.

## System dependencies

**Linux:** `libmpv` (Arch: `mpv`; Debian/Ubuntu: `libmpv-dev`), `ffprobe` (from ffmpeg; still available via `video.Resolution`, unused by the current main-media layout path), a C compiler + X11/GL dev libs (raylib-go builds raylib with cgo), OpenGL 3.3+ (shader is `#version 330`), a real display. Optional: `labwc` + `xorg-xwayland` for `make labwc`. On Arch `make build` installs all of these automatically.

**Windows:** Go + MSYS2 MinGW (`mingw-w64-x86_64-gcc`) + `libmpv-2.dll` (or `libmpv.dll`) in `deps\` next to the exe + OpenGL. Optional: ffmpeg (`ffprobe`) on PATH. See [`scripts/windows/README.md`](../scripts/windows/README.md).

**Media tip:** prefer H.264 (or HEVC) in `.mp4` for the main card. A 1920×1080 `.mov` is fine when it is H.264/HEVC; ProRes / Animation / high-bitrate mezzanine `.mov` files still decode heavily even after the GPU layout path and can stutter on the kiosk machine. Remux/transcode with ffmpeg if needed:
`ffmpeg -i input.mov -c:v libx264 -pix_fmt yuv420p -c:a aac output.mp4`

## Environment variables (read in `main.go`)

| Var | Default | Notes |
|---|---|---|
| `FPS` | 60 | positive int |
| `ZOOM` | 1.2 | float > 0; invalid values are logged and ignored |
| `RL_LOG` | (warnings only) | `info` / `debug` restore raylib's verbose logging (default hides ~3000 emoji-load lines) |

`.env.example` lists these. Kiosk autostart: Linux `deploy/ece-screen.service` (systemd user unit); Windows `deploy/ece-screen-windows.bat` (Startup folder / Task Scheduler).

## CLI behaviour

`db.InitPocketBase`: with no CLI args it appends `serve --http=0.0.0.0:8090`. With any args they pass straight to PocketBase (so `go run . serve --http=127.0.0.1:8090` works; other args may make PB exit).

## First-time setup

1. `go run .` with no `pb_data/` → PocketBase creates it, `EnsureSchema` creates all collections with example data ([data-model.md](data-model.md)), and PocketBase prints (and tries to open) a one-time registration URL `http://localhost:8090/_/#/pbinstall/<token>` (valid 30 min). Open it to create the first superuser. Alternative: `go run . superuser upsert EMAIL PASS`.
2. The screen already works with the example data; after registering, edit/replace it at `http://localhost:8090/_/` and it updates live.
3. The URL is only printed while no superuser exists; restart the app to get a fresh one.

## Secrets / git

`.env` and `.env.*` are git-ignored. A GitHub token for pushes is stored in the local `.env` as `GITHUB_TOKEN` (it may be used for pushes). Push with:

```bash
set -a; . ./.env; set +a
git push "https://x-access-token:${GITHUB_TOKEN}@github.com/<owner>/ece-screen.git" main
```
(or configure `gh auth`/a credential helper from the token). The app itself does not read `.env`.

## Working directory matters

`pb_data/` (images/videos) is resolved relative to CWD (via `pb.DataDir()`); `resources/fonts/twemoji` is tried relative to CWD, then to the executable's directory. The Arabic font is embedded in the binary via `go:embed`; the Twemoji PNGs are not.
