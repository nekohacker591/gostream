import os
import subprocess
import sys
import time
from contextlib import contextmanager
from pathlib import Path

IS_WINDOWS = os.name == 'nt'


def default_root_dir() -> str:
    if IS_WINDOWS:
        return os.path.join(os.environ.get('ProgramData', r'C:\ProgramData'), 'GoStream')
    return '/home/pi'


def default_library_dir() -> str:
    if IS_WINDOWS:
        return r'C:\GoStream\library'
    return '/mnt/torrserver'


def default_mount_path() -> str:
    if IS_WINDOWS:
        return 'G:\\'
    return '/mnt/torrserver-go'


def default_logs_dir(config_dir: str) -> str:
    return os.environ.get('GOSTREAM_LOG_DIR', os.path.join(config_dir, 'logs'))


def default_state_dir(config_dir: str) -> str:
    return os.environ.get('GOSTREAM_STATE_DIR', os.path.join(config_dir, 'STATE'))


def _lock_windows(file_obj, blocking: bool) -> None:
    import msvcrt
    mode = msvcrt.LK_LOCK if blocking else msvcrt.LK_NBLCK
    file_obj.seek(0)
    try:
        msvcrt.locking(file_obj.fileno(), mode, 1)
    except OSError:
        if blocking:
            raise
        raise


def _unlock_windows(file_obj) -> None:
    import msvcrt
    file_obj.seek(0)
    try:
        msvcrt.locking(file_obj.fileno(), msvcrt.LK_UNLCK, 1)
    except OSError:
        pass


def _lock_unix(file_obj, blocking: bool) -> None:
    import fcntl
    flags = fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB)
    fcntl.flock(file_obj.fileno(), flags)


def _unlock_unix(file_obj) -> None:
    import fcntl
    fcntl.flock(file_obj.fileno(), fcntl.LOCK_UN)


def lock_file(file_obj, blocking: bool = True) -> None:
    if IS_WINDOWS:
        _lock_windows(file_obj, blocking)
    else:
        _lock_unix(file_obj, blocking)


def unlock_file(file_obj) -> None:
    if IS_WINDOWS:
        _unlock_windows(file_obj)
    else:
        _unlock_unix(file_obj)


@contextmanager
def locked_file(path: str, mode: str = 'a+', blocking: bool = True):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    f = open(path, mode, encoding='utf-8')
    try:
        lock_file(f, blocking=blocking)
        yield f
    finally:
        unlock_file(f)
        f.close()


def restart_local_service(service: str) -> subprocess.CompletedProcess:
    if IS_WINDOWS:
        return subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', f'Restart-Service -Name {service} -Force'], capture_output=True, text=True, timeout=30)
    return subprocess.run(['sudo', 'systemctl', 'restart', service], capture_output=True, text=True, timeout=30)


def tail_file(path: str, lines: int) -> subprocess.CompletedProcess:
    if IS_WINDOWS:
        cmd = [
            'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
            f"Get-Content -Path '{path}' -Tail {lines}"
        ]
        return subprocess.run(cmd, capture_output=True, text=True, errors='ignore')
    return subprocess.run(['tail', '-n', str(lines), path], capture_output=True, text=True, errors='ignore')
