//go:build !windows

package components

// InitVideoHost is a no-op outside Windows (Linux uses fullscreen + punch-hole).
func InitVideoHost() int64 { return 0 }

// SyncVideoHost is a no-op outside Windows.
func SyncVideoHost(x, y, w, h int32, show bool) {}

// DestroyVideoHost is a no-op outside Windows.
func DestroyVideoHost() {}
