"""Build the user-installable extension from workspace assets only."""
from datetime import date
import os
from pathlib import Path
import subprocess
import sys
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parent.parent
RELEASE_ENTRIES = ('init.lua', 'pkg', 'image', 'audio')
DIST_DIR = ROOT / '.dev/dist'


def release_output_path():
    commit = subprocess.check_output(
        ['git', 'rev-parse', '--short=8', 'HEAD'], cwd=ROOT, text=True,
    ).strip()
    return DIST_DIR / f'qiao-{date.today().isoformat()}-{commit}.zip'


def build(output=None):
    output = release_output_path() if output is None else Path(output)
    files = []
    for entry in RELEASE_ENTRIES:
        source = ROOT / entry
        if not source.exists():
            raise FileNotFoundError(source)
        files.extend([source] if source.is_file() else sorted(source.rglob('*')))
    files = [path for path in files if path.is_file() and path.name != '.gitkeep']
    # Resolve paths before packaging so links cannot import development files.
    for path in files:
        relative = path.resolve().relative_to(ROOT.resolve())
        if relative.parts[0] not in RELEASE_ENTRIES:
            raise ValueError(f'File outside release assets: {path}')
    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
        for path in files:
            archive.write(path, 'qiao/' + path.relative_to(ROOT).as_posix())
    print(f'Built {output} ({len(files)} files)')
    return output


if __name__ == '__main__':
    output = build()
    if os.name == 'nt':
        try:
            os.startfile(output.parent)
        except OSError as error:
            print(f'Could not open {output.parent} in File Explorer: {error}', file=sys.stderr)
