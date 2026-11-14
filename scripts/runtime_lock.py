"""Serialize use of the shared FreeKill runtime across processes.

The lock is an advisory OS file lock inside the resolved runtime directory, so
every session that uses that runtime contends for the same lock. The operating
system releases it when the owning process exits, including abnormal exits; a
leftover lock file never keeps the runtime occupied.
"""
from contextlib import contextmanager, suppress
import os
from pathlib import Path
import socket
import time

LOCK_FILE_NAME = '.freekill-test.lock'
# Byte 0 is the lock region; holder metadata starts after it so that a waiting
# process can read the owner's PID without touching the locked byte (Windows
# byte-range locks also block reads of the locked range itself).
_HOLDER_OFFSET = 16
_HOLDER_SIZE = 256


class RuntimeLockError(RuntimeError):
    """The runtime lock cannot be used."""


class RuntimeLockBusy(RuntimeLockError):
    """Another process currently holds the shared runtime lock."""


def lock_path(runtime):
    """Return the shared lock file for ``runtime`` (not a session-local path)."""
    return Path(runtime).resolve() / LOCK_FILE_NAME


def _read_holder(path):
    try:
        with path.open('rb') as handle:
            handle.seek(_HOLDER_OFFSET)
            raw = handle.read(_HOLDER_SIZE)
    except OSError:
        return 'unknown holder'
    text = ' '.join(raw.decode('utf-8', errors='replace').split())
    return text or 'unknown holder'


def _write_holder(fd):
    holder = (
        f'pid={os.getpid()} host={socket.gethostname()} '
        f'since={time.strftime("%Y-%m-%d %H:%M:%S")}'
    )
    data = holder.encode('utf-8')[:_HOLDER_SIZE].ljust(_HOLDER_SIZE, b' ')
    os.lseek(fd, _HOLDER_OFFSET, os.SEEK_SET)
    os.write(fd, data)


def _lock(fd):
    os.lseek(fd, 0, os.SEEK_SET)
    if os.name == 'nt':
        import msvcrt
        msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
    else:
        import fcntl
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)


def _unlock(fd):
    os.lseek(fd, 0, os.SEEK_SET)
    if os.name == 'nt':
        import msvcrt
        msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
    else:
        import fcntl
        fcntl.flock(fd, fcntl.LOCK_UN)


@contextmanager
def runtime_lock(runtime):
    """Hold the shared runtime lock, or fail immediately if it is occupied."""
    path = lock_path(runtime)
    try:
        fd = os.open(path, os.O_RDWR | os.O_CREAT, 0o600)
    except OSError as error:
        raise RuntimeLockError(f'cannot open runtime lock {path}: {error}') from error
    try:
        try:
            _lock(fd)
        except OSError as error:
            holder = _read_holder(path)
            raise RuntimeLockBusy(
                f'shared runtime is busy: {path} ({holder}); '
                'wait for the other test run to exit or use the designated test runner'
            ) from error
        _write_holder(fd)
        try:
            yield path
        finally:
            # Closing the descriptor also releases the OS lock; suppress an
            # explicit unlock error so it cannot hide the body's own failure.
            with suppress(OSError):
                _unlock(fd)
    finally:
        os.close(fd)
