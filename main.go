package main

import (
	_ "embed"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"strconv"

	"mt-y0/ECE-screen/internal/components"
	"mt-y0/ECE-screen/internal/db"
	"mt-y0/ECE-screen/lib/emoji"
	lib "mt-y0/ECE-screen/lib/fonts"
	"mt-y0/ECE-screen/lib/video"

	rl "github.com/gen2brain/raylib-go/raylib"
	"github.com/pocketbase/pocketbase"
)

//go:embed resources/fonts/notokufi.ttf
var arabicFontData []byte

func main() {
	pb := db.InitPocketBase()

	if runtime.GOOS == "windows" {
		// Raylib first so we can create a WS_CHILD host, then embed libmpv via wid.
		initRaylib()
		wid := components.InitVideoHost()
		video.Player = video.MpvInitWithWid(wid)
	} else {
		video.Player = video.MpvInit()
		initRaylib()
	}
	defer video.Player.TerminateDestroy()
	defer rl.CloseWindow()
	defer components.DestroyVideoHost()

	font := lib.LoadFont(arabicFontData)
	emojiAtlas := emoji.Load(resourceDir("resources/fonts/twemoji"))
	defer emojiAtlas.Unload()

	screenSize := [2]int32{int32(rl.GetScreenWidth()), int32(rl.GetScreenHeight())}
	zoom := envFloat("ZOOM", 1.2)
	blue := rl.NewColor(0, 86, 179, 255)
	lightBlue := rl.NewColor(231, 241, 255, 255)
	bgColor := rl.NewColor(248, 249, 250, 255)

	table := components.GetTableLayout(screenSize, zoom)
	defer table.CleanUp()
	bind("table", pb, table.GetData, table.Watch)

	ticker := components.GetTickerBarLayout(screenSize, zoom)
	bind("ticker", pb, ticker.GetData, ticker.Watch)

	professors := components.GetProfessorsBoardLayout(screenSize, zoom)
	defer professors.CleanUp()
	bind("professors", pb, professors.GetData, professors.Watch)

	secMedia := components.GetSecMediaLayout(screenSize, zoom)
	defer secMedia.CleanUp()
	bind("secmedia", pb, secMedia.GetData, secMedia.Watch)

	mainMedia := components.GetMainMediaLayout(screenSize, zoom)
	defer mainMedia.CleanUp()
	bind("mainmedia", pb, mainMedia.GetData, mainMedia.Watch)

	notices := components.GetNoticeBoardLayout(screenSize, zoom)
	defer notices.CleanUp()
	bind("notices", pb, notices.GetData, notices.Watch)

	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(rl.KeyX) {
			break
		}
		mainMedia.TickVideo()

		rl.BeginDrawing()
		rl.ClearBackground(bgColor)
		table.Draw(font, zoom, blue, lightBlue)
		professors.Draw(font, emojiAtlas, zoom, blue, lightBlue)
		secMedia.Draw(font, emojiAtlas, zoom, blue, lightBlue)
		mainMedia.Draw(font, emojiAtlas, zoom, blue, lightBlue)
		ticker.Draw(screenSize, font, emojiAtlas, blue)
		notices.Draw(font, emojiAtlas, zoom, blue, lightBlue)
		mainMedia.PunchHole()
		rl.EndDrawing()
	}
}

func initRaylib() {
	logLevel := rl.LogWarning
	switch os.Getenv("RL_LOG") {
	case "info":
		logLevel = rl.LogInfo
	case "debug":
		logLevel = rl.LogDebug
	}
	rl.SetTraceLogLevel(logLevel)
	// Transparent framebuffer + punch-hole works on Linux compositors.
	// On Windows DWM ignores GL alpha (black hole), so stay opaque and embed mpv.
	if runtime.GOOS != "windows" {
		rl.SetConfigFlags(rl.FlagWindowTransparent)
	}
	rl.InitWindow(0, 0, "ECE screen")
	rl.HideCursor()
	rl.SetTargetFPS(int32(envInt("FPS", 60)))
}

func bind(name string, pb *pocketbase.PocketBase, get func(*pocketbase.PocketBase) error, watch func(*pocketbase.PocketBase)) {
	if err := get(pb); err != nil {
		log.Printf("%s data: %v", name, err)
	}
	watch(pb)
}

func envInt(key string, fallback int) int {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil || n <= 0 {
		log.Printf("ignoring invalid %s=%q; using %d", key, v, fallback)
		return fallback
	}
	return n
}

func envFloat(key string, fallback float64) float64 {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.ParseFloat(v, 64)
	if err != nil || n <= 0 {
		log.Printf("ignoring invalid %s=%q; using %g", key, v, fallback)
		return fallback
	}
	return n
}

func resourceDir(rel string) string {
	if _, err := os.Stat(rel); err == nil {
		return rel
	}
	if exe, err := os.Executable(); err == nil {
		if p := filepath.Join(filepath.Dir(exe), rel); dirExists(p) {
			return p
		}
	}
	return rel
}

func dirExists(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.IsDir()
}
