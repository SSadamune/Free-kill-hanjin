"""Runtime lock tests using real, independent holder processes."""
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[2] / 'scripts'
sys.path.insert(0, str(SCRIPTS))
from runtime_lock import RuntimeLockBusy, lock_path, runtime_lock  # noqa: E402

CHILD = """
import os
import sys
sys.path.insert(0, {scripts!r})
from runtime_lock import runtime_lock
with runtime_lock({runtime!r}):
    print("locked", flush=True)
    {after}
"""


class RuntimeLockTest(unittest.TestCase):
    @staticmethod
    def close_holder(process):
        for stream in (process.stdin, process.stdout, process.stderr):
            if stream is not None:
                try:
                    stream.close()
                except OSError:
                    pass

    def start_holder(self, runtime, after='sys.stdin.readline()'):
        script = CHILD.format(scripts=str(SCRIPTS), runtime=str(runtime), after=after)
        process = subprocess.Popen(
            [sys.executable, '-c', script],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True,
        )
        ready = process.stdout.readline().strip()
        if ready != 'locked':
            process.kill()
            _, stderr = process.communicate(timeout=10)
            process.stdout.close()
            process.stderr.close()
            self.fail(f'holder failed to start: stdout={ready!r} stderr={stderr}')
        return process

    def test_concurrent_process_fails_fast_with_holder_info(self):
        with tempfile.TemporaryDirectory() as tmp:
            runtime = Path(tmp)
            child = self.start_holder(runtime)
            try:
                started = time.monotonic()
                with self.assertRaises(RuntimeLockBusy) as caught:
                    with runtime_lock(runtime):
                        self.fail('second process must not acquire a held lock')
                self.assertLess(time.monotonic() - started, 5)
                message = str(caught.exception)
                self.assertIn(str(lock_path(runtime)), message)
                self.assertIn(f'pid={child.pid}', message)
            finally:
                child.stdin.write('\n')
                child.stdin.flush()
                child.wait(timeout=10)
                self.close_holder(child)

            # Normal exit leaves the lock file behind but releases the lock.
            with runtime_lock(runtime):
                pass
            self.assertTrue(lock_path(runtime).is_file())

    def test_abnormal_exit_releases_lock(self):
        with tempfile.TemporaryDirectory() as tmp:
            runtime = Path(tmp)
            child = self.start_holder(runtime, 'os._exit(7)')
            self.assertEqual(child.wait(timeout=10), 7)
            self.close_holder(child)
            with runtime_lock(runtime):
                pass

    def test_leftover_lock_file_is_not_held(self):
        with tempfile.TemporaryDirectory() as tmp:
            runtime = Path(tmp)
            lock_path(runtime).write_text(
                'pid=999999 host=gone since=2000-01-01', encoding='utf-8')
            with runtime_lock(runtime):
                pass
            with runtime_lock(runtime):
                pass

    def test_failed_body_releases_lock(self):
        with tempfile.TemporaryDirectory() as tmp:
            runtime = Path(tmp)
            with self.assertRaises(RuntimeError):
                with runtime_lock(runtime):
                    raise RuntimeError('body failed')
            with runtime_lock(runtime):
                pass


if __name__ == '__main__':
    unittest.main()
