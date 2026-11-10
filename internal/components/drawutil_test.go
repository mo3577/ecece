package components

import "testing"

func TestContainFit(t *testing.T) {
	// Landscape into landscape box: fill width.
	r := containFit(200, 100, 400, 200)
	if r.Width != 200 || r.Height != 100 || r.X != 0 || r.Y != 0 {
		t.Fatalf("landscape: %+v", r)
	}
	// Portrait into landscape box: letterbox horizontally.
	r = containFit(200, 100, 50, 100)
	if r.Width != 50 || r.Height != 100 || r.X != 75 || r.Y != 0 {
		t.Fatalf("portrait: %+v", r)
	}
	// Zero source stays box-sized at origin.
	r = containFit(200, 100, 0, 0)
	if r.Width != 200 || r.Height != 100 {
		t.Fatalf("zero: %+v", r)
	}
}

func TestMediaWidth(t *testing.T) {
	if got := mediaWidth(100); got != 145 {
		t.Fatalf("mediaWidth(100)=%d", got)
	}
}
