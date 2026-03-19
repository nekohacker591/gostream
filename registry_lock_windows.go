//go:build windows

package main

import (
	"os"
	"syscall"
)

func lockFileExclusive(f *os.File) error {
	var ol syscall.Overlapped
	return syscall.LockFileEx(syscall.Handle(f.Fd()), syscall.LOCKFILE_EXCLUSIVE_LOCK, 0, 1, 0, &ol)
}

func unlockFile(f *os.File) error {
	var ol syscall.Overlapped
	return syscall.UnlockFileEx(syscall.Handle(f.Fd()), 0, 1, 0, &ol)
}
