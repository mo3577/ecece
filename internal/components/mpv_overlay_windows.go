//go:build windows

package components

import (
	"log"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows"
)

const (
	hwndTopmost   = ^uintptr(0) // HWND_TOPMOST ((HWND)-1)
	hwndNotopmost = ^uintptr(1) // HWND_NOTOPMOST ((HWND)-2)
	swpNoActivate = 0x0010
	swpShowWindow = 0x0040
	swpHideWindow = 0x0080
)

var (
	user32          = windows.NewLazySystemDLL("user32.dll")
	procFindWindowW = user32.NewProc("FindWindowW")
	procSetWindowPos = user32.NewProc("SetWindowPos")
	procIsWindow    = user32.NewProc("IsWindow")
	procShowWindow  = user32.NewProc("ShowWindow")
)

const (
	swHide = 0
	swShow = 5
)

const mpvOverlayTitle = "ECE-screen-mpv"

func findMpvHWND() uintptr {
	title, err := windows.UTF16PtrFromString(mpvOverlayTitle)
	if err != nil {
		return 0
	}
	// Prefer title we set from playVideo.
	hwnd, _, _ := procFindWindowW.Call(0, uintptr(unsafe.Pointer(title)))
	if hwnd != 0 {
		return hwnd
	}
	className, err := windows.UTF16PtrFromString("mpv")
	if err != nil {
		return 0
	}
	hwnd, _, _ = procFindWindowW.Call(uintptr(unsafe.Pointer(className)), 0)
	return hwnd
}

func placeMpvOverlay(x, y, w, h int32) {
	hwnd := findMpvHWND()
	if hwnd == 0 {
		log.Printf("windows mpv overlay: window not found yet")
		return
	}
	alive, _, _ := procIsWindow.Call(hwnd)
	if alive == 0 {
		return
	}
	_, _, _ = procShowWindow.Call(hwnd, swShow)
	r, _, callErr := procSetWindowPos.Call(
		hwnd,
		hwndTopmost,
		uintptr(x),
		uintptr(y),
		uintptr(w),
		uintptr(h),
		swpShowWindow|swpNoActivate,
	)
	if r == 0 {
		log.Printf("windows mpv overlay: SetWindowPos failed: %v", callErr)
	}
}

func parkMpvOverlay() {
	hwnd := findMpvHWND()
	if hwnd == 0 {
		return
	}
	_, _, _ = procShowWindow.Call(hwnd, swHide)
	_, _, _ = procSetWindowPos.Call(
		hwnd,
		hwndNotopmost,
		uintptr(int32(-32000)),
		uintptr(int32(-32000)),
		1,
		1,
		swpHideWindow|swpNoActivate,
	)
}

// Keep the syscall import used on older Go toolchains that need it for HWND casts.
var _ = syscall.Handle(0)
