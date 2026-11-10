package components

import (
	"log"
	"sync"
	"sync/atomic"
	"time"

	"mt-y0/ECE-screen/lib/emoji"
	"mt-y0/ECE-screen/lib/raycss"

	rl "github.com/gen2brain/raylib-go/raylib"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

type SecMediaItem struct {
	ImgPath  string
	Duration int
}

type SecondaryMediaCard struct {
	BgRect     rl.Rectangle
	Mask       raycss.MaskContainer
	mu         sync.RWMutex
	dirty      atomic.Bool
	data       []SecMediaItem
	currentIdx int
	lastSwitch time.Time
	Alpha      float32
	loadedPath string
	currentTex rl.Texture2D
	hasTexture bool
}

func GetSecMediaLayout(screenSize [2]int32, zoom float64) *SecondaryMediaCard {
	margin := raycss.S(15).Scale(zoom)
	bgHeight := secMediaHeight(screenSize[1])
	bgWidth := mediaWidth(bgHeight)

	sm := &SecondaryMediaCard{
		BgRect: rl.Rectangle{
			X:      margin.Left,
			Y:      float32(screenSize[1])*tickerTopFrac - float32(bgHeight) - margin.Bottom,
			Width:  float32(bgWidth),
			Height: float32(bgHeight),
		},
		Mask:       raycss.NewMaskContainer(bgWidth, bgHeight, cardRadius*float32(zoom)),
		lastSwitch: time.Now(),
		Alpha:      255,
		currentIdx: 1,
	}
	sm.dirty.Store(true)
	return sm
}

func (l *SecondaryMediaCard) GetData(pb *pocketbase.PocketBase) error {
	col, err := pb.FindCollectionByNameOrId("Media")
	if err != nil {
		return err
	}
	records, err := pb.FindRecordsByFilter("Media", "main_only = false", "+display_order", 500, 0)
	if err != nil {
		return err
	}

	data := make([]SecMediaItem, 0, len(records))
	for _, r := range records {
		imgFile := r.GetString("file")
		if imgFile == "" || isVideo(imgFile) {
			continue
		}
		dur := r.GetInt("duration")
		if dur <= 0 {
			dur = 10
		}
		data = append(data, SecMediaItem{
			ImgPath:  storagePath(pb, col.Id, r.Id, imgFile),
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

func (l *SecondaryMediaCard) Watch(pb *pocketbase.PocketBase) {
	reload := func(e *core.RecordEvent) error {
		if err := l.GetData(pb); err != nil {
			log.Printf("secmedia reload: %v", err)
		}
		return e.Next()
	}
	pb.OnRecordAfterCreateSuccess("Media").BindFunc(reload)
	pb.OnRecordAfterUpdateSuccess("Media").BindFunc(reload)
	pb.OnRecordAfterDeleteSuccess("Media").BindFunc(reload)
}

func (l *SecondaryMediaCard) cycle() {
	l.mu.Lock()
	if len(l.data) > 0 {
		l.currentIdx = (l.currentIdx + 1) % len(l.data)
	}
	l.lastSwitch = time.Now()
	l.mu.Unlock()
	l.Alpha = 0
}

func (l *SecondaryMediaCard) CleanUp() {
	if l.hasTexture {
		rl.UnloadTexture(l.currentTex)
		l.hasTexture = false
	}
	l.Mask.Unload()
}

func (l *SecondaryMediaCard) Draw(font *rl.Font, emojiAtlas *emoji.Atlas, zoom float64, blue, lblue rl.Color) {
	l.mu.RLock()
	data := l.data
	idx := l.currentIdx
	lastSwitch := l.lastSwitch
	l.mu.RUnlock()

	if len(data) > 1 {
		dur := time.Duration(data[idx].Duration) * time.Second
		if time.Since(lastSwitch) >= dur {
			l.cycle()
			l.mu.RLock()
			data = l.data
			idx = l.currentIdx
			l.mu.RUnlock()
		}
	}

	imgPath := ""
	if len(data) > 0 {
		imgPath = data[idx].ImgPath
	}
	if imgPath != l.loadedPath {
		if l.hasTexture {
			rl.UnloadTexture(l.currentTex)
			l.hasTexture = false
		}
		if imgPath != "" {
			if tex, ok := loadTexture(imgPath); ok {
				rl.SetTextureFilter(tex, rl.FilterBilinear)
				l.currentTex = tex
				l.hasTexture = true
			}
		}
		l.loadedPath = imgPath
	}

	needsRender := l.dirty.Swap(false) || stepFade(&l.Alpha)
	if needsRender {
		l.Mask.PreRender(rl.White, func() {
			rl.DrawRectangle(0, 0, int32(l.BgRect.Width), int32(l.BgRect.Height), rl.White)
			if l.hasTexture {
				drawContainTexture(l.currentTex, l.BgRect.Width, l.BgRect.Height)
			}
			drawFadeOverlay(l.BgRect.Width, l.BgRect.Height, l.Alpha)
		})
	}

	raycss.DrawSoftShadow(l.BgRect, cardRadius*float32(zoom), shadowSegs)
	l.Mask.Blit(l.BgRect.X, l.BgRect.Y)
}
