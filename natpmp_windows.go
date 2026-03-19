//go:build windows

package main

import (
	"log"
	"os/exec"
	"strconv"
	"sync/atomic"
	"time"

	"gostream/internal/gostorm/settings"
	"gostream/internal/gostorm/torr"

	natpmp "github.com/jackpal/go-nat-pmp"
)

var currentNatPort int64

// NatPMPConfig holds the configuration for NAT-PMP port forwarding.
type NatPMPConfig struct {
	Enabled      bool   `json:"enabled"`
	Gateway      string `json:"gateway"`
	LocalPort    int    `json:"local_port"`
	VPNInterface string `json:"vpn_interface"`
	Lifetime     int    `json:"lifetime"`
	Refresh      int    `json:"refresh"`
}

func natpmpLoop(stopChan <-chan struct{}, cfg NatPMPConfig, logger *log.Logger) {
	if !cfg.Enabled || cfg.Gateway == "" {
		return
	}
	if cfg.LocalPort == 0 {
		cfg.LocalPort = 8091
	}
	if cfg.Lifetime == 0 {
		cfg.Lifetime = 60
	}
	if cfg.Refresh == 0 {
		cfg.Refresh = 45
	}

	logger.Printf("[NatPMP] Starting Windows NAT-PMP loop — gateway=%s localPort=%d lifetime=%ds refresh=%ds",
		cfg.Gateway, cfg.LocalPort, cfg.Lifetime, cfg.Refresh)

	currentExternalPort := 0
	if settings.BTsets != nil && settings.BTsets.PeersListenPort > 0 {
		currentExternalPort = settings.BTsets.PeersListenPort
		atomic.StoreInt64(&currentNatPort, int64(currentExternalPort))
	}

	for {
		client := natpmp.NewClient(cfg.Gateway)
		tcpResult, err := client.AddPortMapping("tcp", cfg.LocalPort, currentExternalPort, cfg.Lifetime)
		if err != nil {
			logger.Printf("[NatPMP] ERROR: TCP mapping failed: %v — retrying in 10s", err)
			select {
			case <-stopChan:
				return
			case <-time.After(10 * time.Second):
				continue
			}
		}

		externalPort := int(tcpResult.MappedExternalPort)
		if _, err := client.AddPortMapping("udp", cfg.LocalPort, externalPort, cfg.Lifetime); err != nil {
			logger.Printf("[NatPMP] WARNING: UDP mapping failed: %v", err)
		}

		if externalPort != currentExternalPort {
			logger.Printf("[NatPMP] Port changed: %d → %d", currentExternalPort, externalPort)
			configureWindowsPortProxy(cfg.LocalPort, externalPort, logger)
			updateGoStormPort(externalPort, currentExternalPort, logger)
			currentExternalPort = externalPort
			atomic.StoreInt64(&currentNatPort, int64(externalPort))
		}

		select {
		case <-stopChan:
			logger.Println("[NatPMP] Windows shutdown — removing portproxy rules")
			removeWindowsPortProxy(cfg.LocalPort, logger)
			if currentExternalPort > 0 {
				client.AddPortMapping("tcp", 0, currentExternalPort, 0)
				client.AddPortMapping("udp", 0, currentExternalPort, 0)
			}
			return
		case <-time.After(time.Duration(cfg.Refresh) * time.Second):
		}
	}
}

func configureWindowsPortProxy(localPort, externalPort int, logger *log.Logger) {
	removeWindowsPortProxy(localPort, logger)
	port := strconv.Itoa(localPort)
	connectPort := strconv.Itoa(externalPort)
	cmd := exec.Command("netsh", "interface", "portproxy", "add", "v4tov4", "listenaddress=0.0.0.0", "listenport="+port, "connectaddress=127.0.0.1", "connectport="+connectPort)
	if out, err := cmd.CombinedOutput(); err != nil {
		logger.Printf("[NatPMP] WARNING: netsh portproxy add failed: %s — %v", string(out), err)
	}
	fw := exec.Command("netsh", "advfirewall", "firewall", "add", "rule", "name=GoStream NAT-PMP "+port, "dir=in", "action=allow", "protocol=TCP", "localport="+port)
	if out, err := fw.CombinedOutput(); err != nil {
		logger.Printf("[NatPMP] WARNING: firewall rule add failed: %s — %v", string(out), err)
	}
}

func removeWindowsPortProxy(localPort int, logger *log.Logger) {
	port := strconv.Itoa(localPort)
	cmd := exec.Command("netsh", "interface", "portproxy", "delete", "v4tov4", "listenaddress=0.0.0.0", "listenport="+port)
	cmd.CombinedOutput()
	fw := exec.Command("netsh", "advfirewall", "firewall", "delete", "rule", "name=GoStream NAT-PMP "+port)
	fw.CombinedOutput()
}

func updateGoStormPort(newPort, oldPort int, logger *log.Logger) {
	currentSets := settings.BTsets
	if currentSets == nil {
		logger.Printf("[NatPMP] WARNING: BTsets is nil, cannot update port")
		return
	}
	if currentSets.PeersListenPort == newPort {
		return
	}
	newSets := *currentSets
	newSets.PeersListenPort = newPort
	logger.Printf("[NatPMP] GoStorm port updating: %d → %d", oldPort, newPort)
	torr.SetSettings(&newSets)
	logger.Printf("[NatPMP] GoStorm port updated: %d → %d", oldPort, newPort)
}
