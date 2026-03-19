//go:build windows

package main

import (
	"fmt"
	"syscall"
)

func lockFile(fd uintptr) error {
	var ol syscall.Overlapped
	err := syscall.LockFileEx(syscall.Handle(fd), syscall.LOCKFILE_EXCLUSIVE_LOCK, 0, 1, 0, &ol)
	if err != nil {
		return fmt.Errorf("lock failed: %w", err)
	}
	return nil
}

func unlockFile(fd uintptr) error {
	var ol syscall.Overlapped
	err := syscall.UnlockFileEx(syscall.Handle(fd), 0, 1, 0, &ol)
	if err != nil {
		return fmt.Errorf("unlock failed: %w", err)
	}
	return nil
}
