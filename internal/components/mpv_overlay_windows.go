//go:build windows

package components

import (
	"log"
	"runtime"
	"syscall"
	"unsafe"

	rl "github.com/gen2brain/raylib-go/raylib"
	"golang.org/x/sys/windows"
)

const videoHostClass = "ECEScreenVideoHost"

var (
	user32                       = windows.NewLazySystemDLL("user32.dll")
	procRegisterClassExW         = user32.NewProc("RegisterClassExW")
	procCreateWindowExW          = user32.NewProc("CreateWindowExW")
	procDestroyWindow            = user32.NewProc("DestroyWindow")
	procShowWindow               = user32.NewProc("ShowWindow")
	procMoveWindow               = user32.NewProc("MoveWindow")
	procSetWindowPos         = user32.NewProc("SetWindowPos")
	procDefWindowProcW       = user32.NewProc("DefWindowProcW")
	procGetModuleHandleW     = windows.NewLazySystemDLL("kernel32.dll").NewProc("GetModuleHandleW")
	procGetStockObject       = windows.NewLazySystemDLL("gdi32.dll").NewProc("GetStockObject")
	videoHostHWND            uintptr
	videoHostWndProcCallback = syscall.NewCallback(videoHostWndProc)
)

const (
	wsChild        = 0x40000000
	wsClipSiblings = 0x04000000
	wsClipChildren = 0x02000000
	swHide         = 0
	swShow         = 5
	blackBrush     = 4 // STOCK_OBJECT BLACK_BRUSH
	swpNoZOrder    = 0x0004
	swpNoActivate  = 0x0010
	swpShowWindow  = 0x0040
)

type wndClassEx struct {
	Size       uint32
	Style      uint32
	WndProc    uintptr
	ClsExtra   int32
	WndExtra   int32
	Instance   windows.Handle
	Icon       windows.Handle
	Cursor     windows.Handle
	Background windows.Handle
	MenuName   *uint16
	ClassName  *uint16
	IconSm     windows.Handle
}

func videoHostWndProc(hwnd, msg, wParam, lParam uintptr) uintptr {
	ret, _, _ := procDefWindowProcW.Call(hwnd, msg, wParam, lParam)
	return ret
}

// InitVideoHost creates a hidden WS_CHILD of the raylib HWND for libmpv wid embedding.
// Call only after rl.InitWindow on Windows. Returns wid (32-bit HWND as int64).
func InitVideoHost() int64 {
	runtime.LockOSThread()
	parent := uintptr(rl.GetWindowHandle())
	if parent == 0 {
		log.Printf("windows video host: GetWindowHandle returned nil")
		return 0
	}

	hInstance, _, _ := procGetModuleHandleW.Call(0)
	className, err := windows.UTF16PtrFromString(videoHostClass)
	if err != nil {
		log.Printf("windows video host: class name: %v", err)
		return 0
	}

	brush, _, _ := procGetStockObject.Call(blackBrush)
	wc := wndClassEx{
		Size:       uint32(unsafe.Sizeof(wndClassEx{})),
		WndProc:    videoHostWndProcCallback,
		Instance:   windows.Handle(hInstance),
		Background: windows.Handle(brush),
		ClassName:  className,
	}
	atom, _, callErr := procRegisterClassExW.Call(uintptr(unsafe.Pointer(&wc)))
	if atom == 0 {
		// Already registered in this process is fine.
		log.Printf("windows video host: RegisterClassEx: %v (continuing)", callErr)
	}

	hwnd, _, callErr := procCreateWindowExW.Call(
		0,
		uintptr(unsafe.Pointer(className)),
		0,
		wsChild|wsClipSiblings|wsClipChildren, // start hidden (no WS_VISIBLE)
		0, 0, 1, 1,
		parent,
		0,
		hInstance,
		0,
	)
	if hwnd == 0 {
		log.Printf("windows video host: CreateWindowEx failed: %v", callErr)
		return 0
	}
	videoHostHWND = hwnd
	_, _, _ = procShowWindow.Call(hwnd, swHide)

	// Win32 HWND fits in 32 bits; mpv requires the truncated form.
	wid := int64(uint32(hwnd))
	log.Printf("windows video host: hwnd=%#x wid=%d", hwnd, wid)
	return wid
}

// SyncVideoHost moves/shows the embed host over the main-media card.
func SyncVideoHost(x, y, w, h int32, show bool) {
	if videoHostHWND == 0 || w <= 0 || h <= 0 {
		return
	}
	_, _, _ = procMoveWindow.Call(videoHostHWND, uintptr(x), uintptr(y), uintptr(w), uintptr(h), 1)
	if show {
		_, _, _ = procShowWindow.Call(videoHostHWND, swShow)
		_, _, _ = procSetWindowPos.Call(videoHostHWND, 0, uintptr(x), uintptr(y), uintptr(w), uintptr(h), swpNoZOrder|swpNoActivate|swpShowWindow)
	} else {
		_, _, _ = procShowWindow.Call(videoHostHWND, swHide)
	}
}

// DestroyVideoHost destroys the child host (call on shutdown if needed).
func DestroyVideoHost() {
	if videoHostHWND == 0 {
		return
	}
	_, _, _ = procDestroyWindow.Call(videoHostHWND)
	videoHostHWND = 0
}
