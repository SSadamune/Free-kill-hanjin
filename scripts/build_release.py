"""Build the user-installable extension from workspace assets only."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parent.parent
RELEASE_ENTRIES = ('init.lua', 'pkg', 'image', 'audio')
OUTPUT = ROOT / '.dev/dist/hanjin.zip'


def build(output=OUTPUT):
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
            archive.write(path, 'hanjin/' + path.relative_to(ROOT).as_posix())
    print(f'Built {output} ({len(files)} files)')
    return output


if __name__ == '__main__':
    build()
