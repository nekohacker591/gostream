//go:build windows

package main

import (
	"os"

	"golang.org/x/sys/windows"
)

func lockFileExclusive(f *os.File) (func(), error) {
	var ol windows.Overlapped
	err := windows.LockFileEx(windows.Handle(f.Fd()), windows.LOCKFILE_EXCLUSIVE_LOCK, 0, 1, 0, &ol)
	if err != nil {
		return nil, err
	}
	return func() { _ = windows.UnlockFileEx(windows.Handle(f.Fd()), 0, 1, 0, &ol) }, nil
}
