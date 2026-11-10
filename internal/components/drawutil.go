package components

import rl "github.com/gen2brain/raylib-go/raylib"

// containFit returns a destination rect that fits srcW×srcH inside boxW×boxH
// while preserving aspect ratio and centering.
func containFit(boxW, boxH, srcW, srcH float32) rl.Rectangle {
	if srcW <= 0 || srcH <= 0 {
		return rl.NewRectangle(0, 0, boxW, boxH)
	}
	scale := boxW / srcW
	if boxH/srcH < scale {
		scale = boxH / srcH
	}
	drawW := srcW * scale
	drawH := srcH * scale
	return rl.NewRectangle((boxW-drawW)/2, (boxH-drawH)/2, drawW, drawH)
}

// stepFade advances a 0→255 fade-in driven at ~510 units/s (~0.5 s).
// Returns whether the frame still needs a mask re-render.
func stepFade(alpha *float32) bool {
	if *alpha >= 255 {
		return false
	}
	*alpha += 510 * rl.GetFrameTime()
	if *alpha > 255 {
		*alpha = 255
	}
	return true
}

func drawFadeOverlay(w, h float32, alpha float32) {
	if alpha >= 255 {
		return
	}
	rl.DrawRectangle(0, 0, int32(w), int32(h),
		rl.NewColor(255, 255, 255, uint8(255-alpha)))
}

func drawContainTexture(tex rl.Texture2D, boxW, boxH float32) {
	src := rl.NewRectangle(0, 0, float32(tex.Width), float32(tex.Height))
	dst := containFit(boxW, boxH, src.Width, src.Height)
	rl.DrawTexturePro(tex, src, dst, rl.Vector2{}, 0, rl.White)
}
