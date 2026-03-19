package main

import (
	"os"
	"path/filepath"
	"runtime"
)

func defaultRootPath() string {
	if runtime.GOOS == "windows" {
		if base, err := os.UserConfigDir(); err == nil {
			return filepath.Join(base, "GoStream")
		}
		if home, err := os.UserHomeDir(); err == nil {
			return filepath.Join(home, "AppData", "Roaming", "GoStream")
		}
		return filepath.Join("C:\\", "GoStream")
	}
	return "/home/pi"
}

func defaultStateDir() string {
	return filepath.Join(defaultRootPath(), "STATE")
}

func defaultLogDir() string {
	return filepath.Join(defaultRootPath(), "logs")
}
