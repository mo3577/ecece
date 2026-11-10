# Changelog

_Last updated: 2026-11-10_


Newest first. Every code or doc change gets a dated entry (`YYYY-MM-DD`).

## 2026-11-10
- Windows build.ps1: `go build -tags nocgo` so go-mpv uses purego/`libmpv.dll` (fixes missing `mpv/client.h`).
- Windows doctor.ps1: fix `$script:bad++` (PS 5.1), auto-prepend `C:\msys64\mingw64\bin` when checking gcc.
- Windows PowerShell scripts: replace Unicode em-dashes with ASCII so Windows PowerShell 5.1 does not parse-fail on UTF-8 downloads.
- Windows support: `scripts/windows/{doctor,build,run}.ps1`, root `build.bat`/`run.bat`, `deploy/ece-screen-windows.bat` kiosk launcher, `deps/README.txt` for libmpv DLL. Docs: operations, README, `scripts/windows/README.md`.
- Configurable classes/sections: new PocketBase `Stages` + `Sections` collections drive how many class cards appear and which section columns each has (`morning` / `evening` / `all`). Schedule strip rebuilds live; `Schedules.stage` max raised to 20. Docs: data-model, components.
- Cleanup: shared `layout.go` / `drawutil.go` / `texture.go`; main media video tick+hole moved onto the card (`TickVideo`/`PunchHole`); `main.go` bind/env helpers; contain-fit/fade helpers reused by media cards. Docs: components, architecture.

## 2026-11-09
- Video playback fix: the `video-margin-ratio` + `hwdec=auto-safe` path could show nothing / die early on .mov. Restored card positioning with `scale=…:flags=fast_bilinear,pad=…` (still no heavy `lavfi=[]` wrapper), `hwdec=no`, and end-of-video detection that waits until mpv has actually left idle (`videoSeenPlaying`) with a 15 s load timeout.
- Schedules exam mode: new `is_exam` bool (seeded + additive migration for existing DBs). Exam rows are highlighted with a warm strip and `امتحان` badge. Section `A` or `B` shows the exam in both morning columns; `مسائي` shows it only in the evening column. Docs: data-model, components; unit tests for `sectionMatches`.
- Main media video (earlier): dropped `lavfi=[scale,pad]` stutter path; later revised again (see above) after field reports of broken playback.
- Fixed S-06: lone video replays via `HandleVideoEnded`, timed image cycling skipped for a single item (no more every-frame cycle after a finished video).
- UI scale: default `ZOOM` 1.0 → 1.2; content band `0.30/0.65` → `0.28/0.67` (shared layout fractions); professor portrait 42% → 48%; ticker font follows `ZOOM`. Docs: architecture, operations, README, `.env.example`.
- Docs: components, architecture, suggestions, AGENTS.md.

## 2026-10-24 (eleventh update)
- Shadows now match card corners: `DrawSoftShadow` takes a pixel radius (was raylib's min-side-relative roundness 0.05, which gave much tighter corners than the mask's `cardRadius`); each layer adds spread/2. Removed `shadowRound`. Docs: components, libraries.

## 2026-10-24 (tenth update)
- Removed the "don't print/use the token" restrictions from CLAUDE.md, AGENTS.md and docs/operations.md; `GITHUB_TOKEN` in `.env` may be used for pushes.

## 2026-10-24 (ninth update)
- Ticker bar: two copies exactly one screen width apart (start to start, period = max(screenW, textW)); a copy reaching the right corner reappears at the left corner. Docs: components.

## 2026-10-24 (eighth update)
- Ticker bar: two copies, one screen width apart, so the next copy enters right as the previous leaves (no empty bar). Docs: components.

## 2026-10-24 (seventh update)
- Ticker bar: now a single copy scrolls right and re-enters from the left only after the whole sentence has left the right edge (period = screenW + textW), instead of a seamless repeating loop. Docs: components.

## 2026-10-24 (sixth update)
- `scripts/tui.sh`: new `deps` command — on Arch installs missing `go gcc pkgconf mpv ffmpeg libx11 libxrandr libxinerama libxcursor libxi libglvnd labwc xorg-xwayland` with `sudo pacman -S --needed`; elsewhere lists them. `doctor` now also checks the C compiler, X11/GL dev libs and labwc.
- `Makefile`: bootstrap (stamp) runs `deps` → `doctor` → `go mod download` and re-runs when `scripts/tui.sh` changes; new targets `make deps` and `make labwc` (`labwc -S ./ECE-screen`).
- Docs updated: operations, README.

## 2026-10-24 (fifth update)
- `suggestions.md` only (no code): recorded analysis notes for S-06/07/08/13/17, closed S-11 (always 16:9) and S-12 (negligible gain) as wontfix, added S-20 (downscale images on load) and S-21 (smaller emoji set), parked the rest until real-display benchmarking.

## 2026-10-24 (fourth update)
- Fixed S-03 (weekday rollover reloads Schedules), S-04 (shrunk subject re-measured), S-05 (ticker: width cached under lock, seamless loop, repeats short text), S-09 (`storagePath` via `pb.DataDir()`, logs missing files), S-10 (`Parse12HourTime` returns an error, accepts `8:00 AM`; bad rows are logged and skipped), S-14 partly (`NoticeBoard.CleanUp` unloads `Mask`), S-16/S-18/S-19 (raylib log level Warning by default + `RL_LOG`, emoji load failures logged, twemoji path falls back to the executable dir).
- `ZOOM` validated (part of S-11). `emoji.Atlas` methods are now really nil-safe (found by a new test).
- S-01 closed as intentional: the server stays bound to `0.0.0.0:8090` so LAN devices can reach the admin UI.
- Added tests (`lib/fonts`, `lib/emoji`, `internal/components`), `.env.example`, `deploy/ece-screen.service`; README Go version corrected.
- Docs updated: components, data-model, libraries, operations, suggestions, AGENTS.md.

## 2026-10-24 (third update)
- Added `Makefile` (help/setup/doctor/build/run/vet/test/fmt/clean/distclean) and `scripts/tui.sh` (playful spinner/banner UI); fresh-clone detection via `.build/deps.stamp` triggers dependency check + `go mod download`. `.build/` git-ignored.
- `gofmt` applied to `internal/components/noticeBoard.go`.
- Docs updated: operations.

## 2026-10-24 (second update)
- `internal/db`: new `schema.go` — `EnsureSchema` creates missing collections (Schedules, TickerBar, Professors, Notices, Media) with example records; `client.go` now runs it from `OnServe` and waits until ready (fixes S-02). PocketBase's built-in installer URL provides first-run superuser registration.
- Docs updated: data-model, operations, architecture, suggestions (S-02 fixed, S-15 amended).

## 2026-10-24
- Added `docs/` (architecture, components, libraries, data-model, operations, conventions, suggestions, this changelog).
- Rewrote `CLAUDE.md` and added `AGENTS.md` as index entries to `docs/`, with the rule "update docs + date on every change".
- Corrected stale notes: 6 components (not 3), `lib/video` is used by main media, emoji draw size is 0.65 (not 0.85).
- Recorded initial review findings S-01…S-15 in `suggestions.md` (no code changed).
