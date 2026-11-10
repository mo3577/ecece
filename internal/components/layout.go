package components

import "math"

// Shared board geometry. All cards derive size/position from these fractions
// of screen height so the 16:9 kiosk layout stays consistent.
const (
	cardRadius = float32(10)
	shadowSegs = int32(8)

	mediaAspect     = 1.454 // width / height for media-shaped cards
	tableBandFrac   = 0.28  // schedule strip height / content Y start
	contentBandFrac = 0.67  // professors + media + notices vertical span
	secMediaFrac    = 0.55  // secondary media height as fraction of content band
	tickerTopFrac   = 0.95  // secondary media bottom-aligns above the ticker
)

func roundPx(v float64) int32 {
	return int32(math.Round(v))
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
