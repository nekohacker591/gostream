"""Cross-platform process file locking for GoStream Python helpers."""
from __future__ import annotations

import os
from contextlib import suppress

IS_WINDOWS = os.name == "nt"

if IS_WINDOWS:
    import msvcrt
else:
    import fcntl


class FileLockError(RuntimeError):
    pass


class FileLock:
    def __init__(self, lock_path: str, pid_path: str | None = None):
        self.lock_path = lock_path
        self.pid_path = pid_path
        self._fh = None

    def acquire(self, blocking: bool = False) -> None:
        os.makedirs(os.path.dirname(self.lock_path), exist_ok=True)
        self._fh = open(self.lock_path, 'a+')
        try:
            if IS_WINDOWS:
                mode = msvcrt.LK_LOCK if blocking else msvcrt.LK_NBLCK
                self._fh.seek(0)
                self._fh.write(' ')
                self._fh.flush()
                self._fh.seek(0)
                msvcrt.locking(self._fh.fileno(), mode, 1)
            else:
                flags = fcntl.LOCK_EX
                if not blocking:
                    flags |= fcntl.LOCK_NB
                fcntl.flock(self._fh.fileno(), flags)
        except OSError as exc:
            self.release()
            raise FileLockError(str(exc)) from exc

        if self.pid_path:
            Path = __import__('pathlib').Path
            Path(self.pid_path).write_text(str(os.getpid()), encoding='utf-8')

    def release(self) -> None:
        if self._fh is not None:
            with suppress(OSError):
                if IS_WINDOWS:
                    self._fh.seek(0)
                    msvcrt.locking(self._fh.fileno(), msvcrt.LK_UNLCK, 1)
                else:
                    fcntl.flock(self._fh.fileno(), fcntl.LOCK_UN)
            with suppress(OSError):
                self._fh.close()
            self._fh = None
        if self.pid_path:
            with suppress(OSError):
                os.remove(self.pid_path)
