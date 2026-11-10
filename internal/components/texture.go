package components

import (
	"image"
	"image/draw"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"unsafe"

	rl "github.com/gen2brain/raylib-go/raylib"
)

func isVideo(path string) bool {
	switch strings.ToLower(filepath.Ext(path)) {
	case ".mp4", ".avi", ".mov", ".mkv", ".webm", ".flv", ".wmv", ".m4v", ".3gp":
		return true
	}
	return false
}

// loadTexture decodes JPEG/PNG/GIF via Go's image package and uploads RGBA to the GPU.
func loadTexture(path string) (rl.Texture2D, bool) {
	f, err := os.Open(path)
	if err != nil {
		return rl.Texture2D{}, false
	}
	defer f.Close()

	src, _, err := image.Decode(f)
	if err != nil {
		return rl.Texture2D{}, false
	}

	b := src.Bounds()
	w, h := int32(b.Dx()), int32(b.Dy())
	rgba := image.NewRGBA(image.Rect(0, 0, int(w), int(h)))
	draw.Draw(rgba, rgba.Bounds(), src, b.Min, draw.Src)

	rlImg := &rl.Image{
		Data:    unsafe.Pointer(&rgba.Pix[0]),
		Width:   w,
		Height:  h,
		Mipmaps: 1,
		Format:  rl.UncompressedR8g8b8a8,
	}
	tex := rl.LoadTextureFromImage(rlImg)
	runtime.KeepAlive(rgba)
	if tex.Width == 0 {
		return rl.Texture2D{}, false
	}
	return tex, true
}
