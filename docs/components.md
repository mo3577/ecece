# Components (`internal/components`)

_Last updated: 2026-11-10_


All components live in package `components`. Shared layout in `layout.go` (`cardRadius`, `shadowSegs`, `mediaAspect=1.454`, band fractions). Shared draw helpers in `drawutil.go` (`containFit`, `stepFade`, `drawContainTexture`). Texture helpers in `texture.go` (`loadTexture`, `isVideo`). Paths in `paths.go`.

Common fields: `BgRect`, `Mask raycss.MaskContainer`, `mu sync.RWMutex`, `dirty atomic.Bool`, `data`, `currentIdx`, `lastSwitch`, `Alpha` (0→255 fade-in, driven at 510/s ≈ 0.5 s), `loadedPath/currentTex/hasTexture` (single cached GPU texture).

| File | Type | Collection | Behaviour |
|---|---|---|---|
| `tableArea.go` | `TableLayout` | `Stages` + `Sections` + `Schedules` | N class cards from `Stages` (ordered by `display_order`). Columns from that stage's `Sections` filtered by `period` (morning before 14:00 / evening after). Lectures from today's `Schedules`. Past rows hidden; exams highlighted and mirrored across same-period sections. |
| `tickerBar.go` | `TickerBarLayout` | `TickerBar` | Concatenates all `text` fields with ` ~ ` separators, reshaped + emoji-split. Scrolls rightwards at `screenW/30` px/s; the text width is measured once per data change (under the lock). Two copies scroll across exactly one screen width apart (start to start); when one's start reaches the right corner it wraps to the left corner, keeping the distance (period = max(screenW, textW)). Blue bar, white text. |
| `professorsBoard.go` | `ProfessorsBoard` | `Professors` (sorted `display_order`) | Cycles every fixed 20 s (`profCycleDuration`). Cropped (cover-fit) photo in its own `imgMask`, name / uppercase role / justified bio. Latin text path (no Reshape of whole card; `FitText` reshapes internally). |
| `secMediaCard.go` | `SecondaryMediaCard` | `Media` where `main_only = false`, images only | Contain-fit image, per-item `duration` (default 10 s). Starts at index 1 so it is out of phase with main media. |
| `mainMediaCard.go` | `MainMediaCard` | `Media` (all) | Images (contain-fit) or video. `playVideo()` contain-fits + `vf=scale/pad` onto fullscreen mpv (`hwdec=no`). `TickVideo()` / `PunchHole()` called from `main`. End after real playback (or 15 s load timeout); lone video replays. |
| `noticeBoard.go` | `NoticeBoard` | `Notices` (sorted `display_order`) | Header "📢اعلانات القسم", body = optional image (top half, contain-fit) + RTL centred text via `FitText` with `UseEmoji`. Text prefixed with 📌. Per-item `duration` (default 10 s). |

## Cycling & fade (identical in all rotating cards)

`Draw` → read-locked snapshot → if elapsed ≥ item duration, `cycle()` (index+1 mod n, reset `lastSwitch`, `Alpha=0`) → if item path changed, unload old texture and load new one **synchronously on the render thread** → if dirty or fading, `Mask.PreRender(...)` (fade = white overlay with alpha `255-Alpha`) → shadow + `Mask.Blit`.

Index is reset to 0 in `GetData` only when it falls out of range.

## Cleanup

Each component with GPU resources has `CleanUp()` (called with `defer` in `main.go`). `NoticeBoard.CleanUp` unloads the texture and its `Mask`; `TickerBarLayout` has none (no GPU resources).

## Adding a new component

1. File `internal/components/<name>.go`, constructor `Get<Name>Layout(screenSize, zoom)`.
2. Implement `GetData(pb)`, `Watch(pb)`, `Draw(...)`, `CleanUp()` following the pattern above (copy `noticeBoard.go`).
3. Register in `main.go` (init, `GetData`, `Watch`, `defer CleanUp`, `Draw` in loop).
4. Update this file, `architecture.md` (layout table), `data-model.md`, and `CHANGELOG.md`.
