//go:build !windows

package components

const mpvOverlayTitle = "ECE-screen-mpv"

func placeMpvOverlay(x, y, w, h int32) {}
func parkMpvOverlay()                   {}
