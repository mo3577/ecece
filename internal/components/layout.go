package components

import "math"

// Shared board geometry. All cards derive size/position from these fractions
// of screen height so the 16:9 kiosk layout stays consistent.
//
// UI constants (font px, padding) are authored for a 1080p baseline and then
// scaled by ResolveZoom so a 4K (2160p) kiosk gets ~2× text/padding.
const (
	cardRadius = float32(10)
	shadowSegs = int32(8)

	mediaAspect     = 1.454 // width / height for media-shaped cards
	tableBandFrac   = 0.28  // schedule strip height / content Y start
	contentBandFrac = 0.67  // professors + media + notices vertical span
	secMediaFrac    = 0.55  // secondary media height as fraction of content band
	tickerTopFrac   = 0.95  // secondary media bottom-aligns above the ticker

	// DesignRefHeight is the vertical reference for ZOOM scaling (4K UHD = 2160).
	// ResolveZoom maps user ZOOM onto the real screen: at 2160p, ZOOM 1.35 ≈ 2.7× 1080 bases.
	DesignRefHeight = 2160.0
	DesignBaseHeight = 1080.0
)

func roundPx(v float64) int32 {
	return int32(math.Round(v))
}

// ResolveZoom scales the user ZOOM for the current screen height.
// Constants were tuned around 1080p; 4K (2160) therefore gets ~2× text size.
func ResolveZoom(screenH int32, userZoom float64) float64 {
	if userZoom <= 0 {
		userZoom = 1.35
	}
	if screenH <= 0 {
		return userZoom
	}
	return userZoom * float64(screenH) / DesignBaseHeight
}

func mediaWidth(height int32) int32 {
	return roundPx(float64(height) * mediaAspect)
}

func secMediaHeight(screenH int32) int32 {
	return roundPx(float64(screenH) * contentBandFrac * secMediaFrac)
}

func contentBandHeight(screenH int32) int32 {
	return roundPx(float64(screenH) * contentBandFrac)
}

func contentTopY(screenH int32, padTop float32) float32 {
	return float32(roundPx(float64(screenH)*tableBandFrac)) + padTop
}
