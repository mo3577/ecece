package components

import (
	"fmt"
	"log"
	"math"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"mt-y0/ECE-screen/lib/emoji"
	"mt-y0/ECE-screen/lib/raycss"
	"mt-y0/ECE-screen/lib/video"

	rl "github.com/gen2brain/raylib-go/raylib"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

const videoLoadTimeout = 15 * time.Second

type MainMediaItem struct {
	FilePath string
	IsVideo  bool
	Duration int
}

type MainMediaCard struct {
	BgRect     rl.Rectangle
	Mask       raycss.MaskContainer
	screenSize [2]int32
	mu         sync.RWMutex
	dirty      atomic.Bool
	data       []MainMediaItem
	currentIdx int
	lastSwitch time.Time
	Alpha      float32
	loadedPath string
	currentTex rl.Texture2D
	hasTexture bool
	IsVideo    bool

	videoStartedAt   time.Time
	videoSeenPlaying bool
}

func GetMainMediaLayout(screenSize [2]int32, zoom float64) *MainMediaCard {
	margin := raycss.S(15).Scale(zoom)
	bgHeight := contentBandHeight(screenSize[1]) - int32(margin.V())
	bgWidth := mediaWidth(bgHeight)
	secH := secMediaHeight(screenSize[1])

	mc := &MainMediaCard{
		BgRect: rl.Rectangle{
			X:      float32(mediaWidth(secH)) + margin.H(),
			Y:      contentTopY(screenSize[1], margin.Top),
			Width:  float32(bgWidth),
			Height: float32(bgHeight),
		},
		Mask:       raycss.NewMaskContainer(bgWidth, bgHeight, cardRadius*float32(zoom)),
		screenSize: screenSize,
		lastSwitch: time.Now(),
		Alpha:      255,
	}
	mc.dirty.Store(true)
	return mc
}

func (l *MainMediaCard) playVideo(path string) {
	rayW := float64(rl.GetScreenWidth())
	rayH := float64(rl.GetScreenHeight())
	if rayW <= 0 || rayH <= 0 {
		rayW, rayH = float64(l.screenSize[0]), float64(l.screenSize[1])
	}
	if rayW <= 0 || rayH <= 0 || l.BgRect.Width <= 0 || l.BgRect.Height <= 0 {
		return
	}

	// Map raylib card coords into mpv's real OSD/fullscreen pixels (Windows
	// DPI / borderless vs exclusive fullscreen often disagree on size).
	mpvW := float64(mpvPropInt("osd-width", int32(rayW)))
	mpvH := float64(mpvPropInt("osd-height", int32(rayH)))
	if mpvW <= 0 {
		mpvW = rayW
	}
	if mpvH <= 0 {
		mpvH = rayH
	}
	sx, sy := mpvW/rayW, mpvH/rayH

	x := int32(math.Round(float64(l.BgRect.X) * sx))
	y := int32(math.Round(float64(l.BgRect.Y) * sy))
	cardW := int32(math.Round(float64(l.BgRect.Width) * sx))
	cardH := int32(math.Round(float64(l.BgRect.Height) * sy))
	sw, sh := int32(math.Round(mpvW)), int32(math.Round(mpvH))
	if cardW <= 0 || cardH <= 0 || sw <= 0 || sh <= 0 {
		return
	}

	// Clear leftover margins; keep software decode for .mov compatibility.
	_ = video.Player.SetPropertyString("video-margin-ratio-left", "0")
	_ = video.Player.SetPropertyString("video-margin-ratio-right", "0")
	_ = video.Player.SetPropertyString("video-margin-ratio-top", "0")
	_ = video.Player.SetPropertyString("video-margin-ratio-bottom", "0")
	_ = video.Player.SetPropertyString("hwdec", "no")
	// Fit inside the card (no ffprobe), center with pad expressions, then
	// place that card-sized frame onto the fullscreen mpv canvas.
	vf := fmt.Sprintf(
		"scale=%d:%d:force_original_aspect_ratio=decrease:flags=fast_bilinear,"+
			"pad=%d:%d:(ow-iw)/2:(oh-ih)/2:black,"+
			"pad=%d:%d:%d:%d:black",
		cardW, cardH, cardW, cardH, sw, sh, x, y,
	)
	_ = video.Player.SetPropertyString("vf", vf)
	_ = video.Player.SetPropertyString("fullscreen", "yes")
	if err := video.Player.Command([]string{"loadfile", path, "replace"}); err != nil {
		log.Printf("mainmedia loadfile %s: %v", path, err)
		l.IsVideo = false
		l.videoSeenPlaying = false
		return
	}
	l.videoStartedAt = time.Now()
	l.videoSeenPlaying = false
	l.IsVideo = true
}

func mpvPropInt(name string, fallback int32) int32 {
	if video.Player == nil {
		return fallback
	}
	s := video.Player.GetPropertyString(name)
	if s == "" {
		return fallback
	}
	n, err := strconv.Atoi(s)
	if err != nil || n <= 0 {
		return fallback
	}
	return int32(n)
}

// TickVideo advances mpv idle/end-of-file state. Call once per frame from main.
func (l *MainMediaCard) TickVideo() {
	if !l.IsVideo {
		return
	}
	if !video.IsIdle() {
		l.videoSeenPlaying = true
		return
	}
	if l.videoSeenPlaying || time.Since(l.videoStartedAt) > videoLoadTimeout {
		l.HandleVideoEnded()
	}
}

// PunchHole clears the card rect so the mpv window underneath shows through.
func (l *MainMediaCard) PunchHole() {
	if !l.IsVideo {
		return
	}
	rl.BeginBlendMode(rl.BlendCustomSeparate)
	rl.SetBlendFactorsSeparate(0, 0, 0, 0, int32(0x8006), int32(0x8006))
	rl.DrawRectangleRounded(l.BgRect, 0.03, 8, rl.White)
	rl.EndBlendMode()
}

func (l *MainMediaCard) HandleVideoEnded() {
	l.mu.RLock()
	n := len(l.data)
	path := ""
	singleVideo := n == 1 && l.data[0].IsVideo
	if singleVideo {
		path = l.data[0].FilePath
	}
	l.mu.RUnlock()

	if singleVideo {
		l.playVideo(path)
		return
	}

	l.IsVideo = false
	l.videoSeenPlaying = false
	video.Unload()
	l.loadedPath = ""
	if n > 1 {
		l.cycle()
	}
}

func (l *MainMediaCard) GetData(pb *pocketbase.PocketBase) error {
	col, err := pb.FindCollectionByNameOrId("Media")
	if err != nil {
		return err
	}
	records, err := pb.FindRecordsByFilter("Media", "", "+display_order", 500, 0)
	if err != nil {
		return err
	}

	data := make([]MainMediaItem, 0, len(records))
	for _, r := range records {
		file := r.GetString("file")
		if file == "" {
			continue
		}
		dur := r.GetInt("duration")
		if dur <= 0 {
			dur = 10
		}
		data = append(data, MainMediaItem{
			FilePath: storagePath(pb, col.Id, r.Id, file),
			IsVideo:  isVideo(file),
			Duration: dur,
		})
	}

	l.mu.Lock()
	l.data = data
	if l.currentIdx >= len(data) {
		l.currentIdx = 0
		l.lastSwitch = time.Now()
	}
	l.mu.Unlock()
	l.dirty.Store(true)
	return nil
}

func (l *MainMediaCard) Watch(pb *pocketbase.PocketBase) {
	reload := func(e *core.RecordEvent) error {
		if err := l.GetData(pb); err != nil {
			log.Printf("mainmedia reload: %v", err)
		}
		return e.Next()
	}
	pb.OnRecordAfterCreateSuccess("Media").BindFunc(reload)
	pb.OnRecordAfterUpdateSuccess("Media").BindFunc(reload)
	pb.OnRecordAfterDeleteSuccess("Media").BindFunc(reload)
}

func (l *MainMediaCard) cycle() {
	l.mu.Lock()
	if len(l.data) > 0 {
		l.currentIdx = (l.currentIdx + 1) % len(l.data)
	}
	l.lastSwitch = time.Now()
	l.mu.Unlock()
	l.Alpha = 0
}

func (l *MainMediaCard) CleanUp() {
	if l.hasTexture {
		rl.UnloadTexture(l.currentTex)
		l.hasTexture = false
	}
	l.Mask.Unload()
}

func (l *MainMediaCard) Draw(font *rl.Font, emojiAtlas *emoji.Atlas, zoom float64, blue, lblue rl.Color) {
	l.mu.RLock()
	data := l.data
	idx := l.currentIdx
	lastSwitch := l.lastSwitch
	l.mu.RUnlock()

	// Timed images only; videos advance from TickVideo/HandleVideoEnded.
	if len(data) > 1 && !l.IsVideo && !data[idx].IsVideo {
		cycleDur := time.Duration(data[idx].Duration) * time.Second
		if time.Since(lastSwitch) >= cycleDur {
			l.cycle()
			l.mu.RLock()
			data = l.data
			idx = l.currentIdx
			l.mu.RUnlock()
		}
	}

	filePath := ""
	if len(data) > 0 {
		filePath = data[idx].FilePath
	}
	if filePath != l.loadedPath {
		if l.hasTexture {
			rl.UnloadTexture(l.currentTex)
			l.hasTexture = false
		}
		if filePath != "" {
			if data[idx].IsVideo {
				l.playVideo(filePath)
			} else if tex, ok := loadTexture(filePath); ok {
				rl.SetTextureFilter(tex, rl.FilterBilinear)
				l.currentTex = tex
				l.hasTexture = true
			}
		}
		l.loadedPath = filePath
	}

	needsRender := l.dirty.Swap(false) || stepFade(&l.Alpha)
	if needsRender {
		l.Mask.PreRender(rl.White, func() {
			rl.DrawRectangle(0, 0, int32(l.BgRect.Width), int32(l.BgRect.Height), rl.White)
			if len(data) == 0 || data[idx].IsVideo {
				// Video: white card; main punches a hole so mpv shows through.
			} else if l.hasTexture {
				drawContainTexture(l.currentTex, l.BgRect.Width, l.BgRect.Height)
			}
			drawFadeOverlay(l.BgRect.Width, l.BgRect.Height, l.Alpha)
		})
	}

	raycss.DrawSoftShadow(l.BgRect, cardRadius*float32(zoom), shadowSegs)
	l.Mask.Blit(l.BgRect.X, l.BgRect.Y)
}
