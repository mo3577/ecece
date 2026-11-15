// Package discovery lets the Flutter admin find this board on the LAN
// without typing an IP. Phones broadcast a UDP probe; we reply with our
// PocketBase base URL.
package discovery

import (
	"fmt"
	"log"
	"net"
	"strconv"
	"strings"
	"sync"
)

const (
	// Port is the UDP discovery port (must match admin/lib/discovery.dart).
	Port = 28090
	// Probe is the exact payload the admin app sends.
	Probe = "ECE-SCREEN-DISCOVER"
	replyPrefix = "ECE-SCREEN "
)

// Start listens for LAN discovery probes and replies with
// "ECE-SCREEN http://<reachable-ip>:<httpPort>". Safe to call once at boot;
// returns a stop function.
func Start(httpPort int) (stop func()) {
	if httpPort <= 0 {
		httpPort = 8090
	}
	conn, err := net.ListenUDP("udp4", &net.UDPAddr{IP: net.IPv4zero, Port: Port})
	if err != nil {
		log.Printf("discovery: listen UDP :%d: %v (admin auto-find disabled)", Port, err)
		return func() {}
	}
	log.Printf("discovery: LAN admin beacon on UDP :%d (HTTP :%d)", Port, httpPort)

	var once sync.Once
	done := make(chan struct{})
	go func() {
		buf := make([]byte, 256)
		for {
			n, remote, err := conn.ReadFromUDP(buf)
			if err != nil {
				select {
				case <-done:
					return
				default:
					log.Printf("discovery: read: %v", err)
					return
				}
			}
			msg := strings.TrimSpace(string(buf[:n]))
			if msg != Probe {
				continue
			}
			url := replyURL(remote.IP, httpPort)
			payload := []byte(replyPrefix + url)
			if _, err := conn.WriteToUDP(payload, remote); err != nil {
				log.Printf("discovery: reply to %v: %v", remote, err)
				continue
			}
			log.Printf("discovery: replied to %v → %s", remote, url)
		}
	}()

	return func() {
		once.Do(func() {
			close(done)
			_ = conn.Close()
		})
	}
}

func replyURL(clientIP net.IP, httpPort int) string {
	ip := bestLocalIPv4(clientIP)
	if ip == "" {
		ip = "127.0.0.1"
	}
	return fmt.Sprintf("http://%s:%d", ip, httpPort)
}

// bestLocalIPv4 picks a non-loopback IPv4 on the same subnet as the client
// when possible, otherwise the first private interface address.
func bestLocalIPv4(client net.IP) string {
	client = client.To4()
	ifaces, err := net.Interfaces()
	if err != nil {
		return ""
	}
	var fallback string
	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, a := range addrs {
			ip, mask := parseIPv4(a)
			if ip == nil {
				continue
			}
			if !ip.IsPrivate() && !ip.IsLinkLocalUnicast() {
				continue
			}
			s := ip.String()
			if fallback == "" {
				fallback = s
			}
			if client != nil && mask != nil && ip.Mask(mask).Equal(client.Mask(mask)) {
				return s
			}
		}
	}
	return fallback
}

func parseIPv4(a net.Addr) (net.IP, net.IPMask) {
	switch v := a.(type) {
	case *net.IPNet:
		ip := v.IP.To4()
		if ip == nil {
			return nil, nil
		}
		return ip, v.Mask
	case *net.IPAddr:
		ip := v.IP.To4()
		if ip == nil {
			return nil, nil
		}
		return ip, net.CIDRMask(24, 32)
	default:
		host, _, err := net.SplitHostPort(a.String())
		if err != nil {
			host = a.String()
		}
		ip := net.ParseIP(host).To4()
		if ip == nil {
			return nil, nil
		}
		return ip, net.CIDRMask(24, 32)
	}
}

// HTTPPortFromArgs reads --http=host:port from os-style serve args, default 8090.
func HTTPPortFromArgs(args []string) int {
	for _, a := range args {
		if !strings.HasPrefix(a, "--http=") {
			continue
		}
		hostPort := strings.TrimPrefix(a, "--http=")
		_, portStr, err := net.SplitHostPort(hostPort)
		if err != nil {
			// bare :8090
			portStr = strings.TrimPrefix(hostPort, ":")
		}
		p, err := strconv.Atoi(portStr)
		if err == nil && p > 0 {
			return p
		}
	}
	return 8090
}
