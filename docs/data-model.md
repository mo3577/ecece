# Data model (PocketBase)

_Last updated: 2026-11-10_

DB lives in `pb_data/` (git-ignored) next to the working directory. Admin UI: `http://localhost:8090/_/`. Collections are **created automatically** on startup by `internal/db/schema.go` (`EnsureSchema`): any missing collection is created with its fields and filled with example records. Existing collections are not recreated; additive field migrations (`Schedules.is_exam`, wider `Schedules.stage` max) still run. Rules are left superuser-only (the app reads through the in-process API). When you change a field in code, update `schema.go` too.

| Collection | Field | Type | Notes |
|---|---|---|---|
| `Stages` | `number` | number | Class id (1–20). Matches `Schedules.stage`. |
| | `title` | text | Card header; empty → `المرحلة{N}` |
| | `display_order` | number | Lower first. Seed puts stage 4 leftmost (RTL). |
| `Sections` | `stage` | number | Parent `Stages.number` |
| | `key` | text | Value stored on `Schedules.section` (`A`, `B`, `مسائي`, …) |
| | `label` | text | Column header text |
| | `period` | text | `morning` (before 14:00), `evening` (from 14:00), or `all` |
| | `display_order` | number | Column order within the stage card |
| `Schedules` | `day` | text | Arabic weekday exactly as in `arabicDays`: `الاحد الاثنين الثلاثاء الاربعاء الخميس الجمعة السبت` (**no hamza** on الاحد/الاربعاء) |
| | `stage` | number | 1–20; must match a `Stages.number` |
| | `section` | text | Must match a `Sections.key` for that stage |
| | `subject`, `hall` | text | hall is rendered as `قاعة <hall>` |
| | `start_time`, `end_time` | text | 12-hour `03:04 PM` (also accepts `3:04 PM`) |
| | `is_exam` | bool | Highlighted. Mirrors across every section that shares the same `period` on that stage |
| `TickerBar` | `text` | text | one message per record |
| `Professors` | `name`, `role`, `bio` | text | role upper-cased on display |
| | `image` | file | |
| | `display_order` | number | |
| `Notices` | `text` | text | Arabic/emoji; prefixed with 📌 |
| | `image` | file | optional |
| | `duration` | number | seconds, ≤0 → 10 |
| | `display_order` | number | |
| `Media` | `file` | file | image or video |
| | `duration` | number | seconds for images, ≤0 → 10 |
| | `main_only` | bool | true → hidden from secondary card |
| | `display_order` | number | |

## Configuring classes & sections

1. Open **Stages** — add/remove records to set how many class cards appear.
2. Open **Sections** — for each stage, add one row per column (`key`, `label`, `period`).
3. Put lectures in **Schedules** using the same `stage` number and section `key`.

Example: 3 classes, stage 2 has three morning sections A/B/C:

- Stages: numbers `1`, `2`, `3`
- Sections for stage 2: `A`/`B`/`C` with `period=morning`, plus optional `مسائي` with `period=evening`

## File paths

Uploaded files: `<pb.DataDir()>/storage/<collectionId>/<recordId>/<filename>`.

## Realtime

Hooks on create/update/delete reload the related components. `Stages` and `Sections` changes rebuild the schedule strip live.
