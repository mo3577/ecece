package discovery

import (
	"net"
	"testing"
)

func TestHTTPPortFromArgs(t *testing.T) {
	if got := HTTPPortFromArgs(nil); got != 8090 {
		t.Fatalf("default: got %d", got)
	}
	if got := HTTPPortFromArgs([]string{"serve", "--http=0.0.0.0:9090"}); got != 9090 {
		t.Fatalf("parsed: got %d", got)
	}
}

func TestReplyURLSameSubnet(t *testing.T) {
	// Smoke: function returns something shaped like a URL for a private client.
	u := replyURL(net.ParseIP("192.168.1.50"), 8090)
	if u == "" || u[:7] != "http://" {
		t.Fatalf("unexpected url %q", u)
	}
}
