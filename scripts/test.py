"""Run FreeKill's native LuaUnit tests with the bundled game runtime."""
import argparse
from pathlib import Path
import re
import subprocess
import sys
from setup_dependencies import verify

ROOT = Path(__file__).resolve().parent.parent
RUNTIME = ROOT / '.dev/runtime/FreeKill-release'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--skills', help='Comma-separated skill names (native addTest cases)')
    parser.add_argument('--file', type=Path, help='External LuaUnit suite; defaults to tests/all.lua')
    parser.add_argument('--timeout', type=int, default=60)
    args = parser.parse_args()
    if args.skills is not None and args.file is not None:
        parser.error('--skills and --file are mutually exclusive')
    exe = RUNTIME / 'FreeKill.exe'
    if not exe.is_file():
        parser.error(f'Missing runtime: {exe}')
    try:
        verify()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'FAIL: {error}\n')
    sync = subprocess.run([
        'powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', str(ROOT / 'scripts/dev.ps1'), '-Action', 'sync',
    ], cwd=ROOT)
    if sync.returncode:
        return sync.returncode
    if args.skills is not None:
        command = [str(exe), '--testskills', args.skills]
    else:
        suite = (args.file or ROOT / 'tests/all.lua').resolve()
        if not suite.is_file():
            parser.error(f'Missing suite: {suite}')
        command = [str(exe), '--testfile', suite.as_posix()]
    try:
        result = subprocess.run(command, cwd=RUNTIME, capture_output=True, timeout=args.timeout)
    except subprocess.TimeoutExpired:
        print(f'FAIL: tests exceeded {args.timeout}s', file=sys.stderr)
        return 1
    output = (result.stdout + result.stderr).decode('utf-8', errors='replace')
    # Preserve diagnostics even when the Windows console banner uses another encoding.
    for line in output.splitlines():
        if line:
            print(line)
    if result.returncode:
        print(f'FAIL: FreeKill exited with code {result.returncode}', file=sys.stderr)
        return 1
    if re.search(r'Main\[(?:C|F)\]', output) or 'stack traceback:' in output:
        print('FAIL: runtime reported a critical Lua/load error', file=sys.stderr)
        return 1
    if not re.search(r'Ran [1-9]\d* tests? .*\b0 failures\b', output):
        print('FAIL: no successful non-empty LuaUnit summary found', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
