package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

func defaultRootPath() string {
	if runtime.GOOS == "windows" {
		if programData := os.Getenv("ProgramData"); programData != "" {
			return filepath.Join(programData, "GoStream")
		}
		return `C:\GoStream`
	}
	if home, err := os.UserHomeDir(); err == nil && home != "" {
		return filepath.Join(home, "GoStream")
	}
	return "/home/pi"
}

func defaultPhysicalSourcePath() string {
	if runtime.GOOS == "windows" {
		return `C:\GoStream\library`
	}
	return "/mnt/torrserver"
}

func defaultVirtualMountPath() string {
	if runtime.GOOS == "windows" {
		return `G:\`
	}
	return "/mnt/torrserver-go"
}

func countBlockedSambaProcesses() int {
	if runtime.GOOS == "windows" {
		return 0
	}
	out, err := exec.Command("ps", "-eo", "stat,comm").Output()
	if err != nil {
		return 0
	}
	count := 0
	for _, line := range strings.Split(string(out), "\n") {
		fields := strings.Fields(line)
		if len(fields) >= 2 && len(fields[0]) > 0 && fields[0][0] == 'D' && fields[1] == "smbd" {
			count++
		}
	}
	return count
}
