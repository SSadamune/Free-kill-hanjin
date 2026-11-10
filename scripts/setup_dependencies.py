"""Install or verify the exact FreeKill extension revisions in dependencies.lock.json."""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
RUNTIME = ROOT / '.dev/runtime/FreeKill-release'


def git(*args, cwd=None):
    return subprocess.check_output(['git', *args], cwd=cwd, text=True, encoding='utf-8').strip()


def verify(install=False, include_references=False):
    lock = json.loads((ROOT / 'dependencies.lock.json').read_text(encoding='utf-8'))
    version = (RUNTIME / 'fk_ver').read_text(encoding='utf-8').strip()
    if version != lock['runtime']:
        raise RuntimeError(f'Expected runtime {lock["runtime"]}, found {version}')
    entries = [(package, RUNTIME / 'packages') for package in lock['packages']]
    if include_references:
        entries += [(reference, ROOT / '.dev/reference') for reference in lock.get('references', [])]
    for package, parent in entries:
        path = parent / package['name']
        if not path.exists() and install:
            subprocess.run(['git', 'clone', package['url'], str(path)], check=True)
            subprocess.run(['git', '-C', str(path), 'checkout', '--detach', package['commit']], check=True)
        if not (path / '.git').exists():
            raise RuntimeError(f'Missing dependency {package["name"]}; run python scripts/setup_dependencies.py')
        if git('status', '--porcelain', cwd=path):
            raise RuntimeError(f'Dependency has local changes: {path}; preserve and review them first')
        revision = git('rev-parse', 'HEAD', cwd=path)
        if revision != package['commit']:
            raise RuntimeError(f'{package["name"]}: expected {package["commit"]}, found {revision}; no changes made')
        print(f'OK {package["name"]} {revision[:12]}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify without installing or updating')
    parser.add_argument('--references', action='store_true', help='Also install/verify optional reference source repositories')
    args = parser.parse_args()
    try:
        verify(install=not args.check, include_references=args.references)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'FAIL: {error}\n')
