"""Verify the image batch, its registered path coverage and release copies.

Usage:
    python scripts/verify_image_assets.py              # batch specs + coverage
    python scripts/verify_image_assets.py --release    # built .dev/dist/qiao.zip
    python scripts/verify_image_assets.py --sync DIR   # an isolated dev.ps1 sync
"""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RELEASE_ENTRIES = ('init.lua', 'pkg', 'image', 'audio')
RELEASE_IMAGE = Path('image/generals')
GUEST_IMAGE = Path('image/generals/guest')
BATCH_COUNTS = {RELEASE_IMAGE: 377, GUEST_IMAGE: 147}
BATCH_SIZE = (250, 292)
BATCH_COMPONENTS = 3

SOF_MARKERS = {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
               0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b''):
            value.update(chunk)
    return value.hexdigest()


def jpeg_info(path):
    """Return (width, height, components, has_icc) without decoding pixels."""
    data = path.read_bytes()
    if not data.startswith(b'\xff\xd8\xff'):
        raise ValueError('not a JPEG file')
    pos, size, components, has_icc = 2, None, None, False
    while pos + 4 <= len(data):
        if data[pos] != 0xFF:
            raise ValueError(f'malformed marker at byte {pos}')
        marker = data[pos + 1]
        if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
            pos += 2
            continue
        length = int.from_bytes(data[pos + 2:pos + 4], 'big')
        if marker == 0xE2 and data[pos + 4:pos + 16].startswith(b'ICC_PROFILE\x00'):
            has_icc = True
        if marker in SOF_MARKERS:
            height = int.from_bytes(data[pos + 5:pos + 7], 'big')
            width = int.from_bytes(data[pos + 7:pos + 9], 'big')
            components = data[pos + 9]
            size = (width, height)
        if marker == 0xDA:
            break
        pos += 2 + length
    if size is None or components is None:
        raise ValueError('missing JPEG frame header')
    return size[0], size[1], components, has_icc


def registered_ids():
    text = (ROOT / 'pkg/qiao_generals/data/standard.lua').read_text(encoding='utf-8')
    generals = text[text.index('M.generals'):text.index('M.retinues')]
    entries = re.findall(
        r'number = \[=\=\[([^\]]*)\]=\=\],\s*id = \[=\=\[([^\]]+)\]=\=\],.*?guests = \{([^}]*)\}',
        generals, re.S)
    general_ids = [entry[1] for entry in entries]
    guest_ids = [entry[1] for entry in entries if entry[2].strip()]
    retinues = text[text.index('M.retinues'):text.index('M.commanders')]
    retinue_ids = [name for name in re.findall(
        r'id = \[=\=\[(qiao_heg__retinue_[^\]]+)\]=\=\]', retinues) if '_skill_' not in name]
    return general_ids, guest_ids, retinue_ids


def check_assets():
    errors = []
    batch = []
    for directory, expected in BATCH_COUNTS.items():
        files = sorted((ROOT / directory).glob('*.jpg'))
        batch.extend(files)
        if len(files) != expected:
            errors.append(f'{directory}: {len(files)} JPEG files, expected {expected}')
    if len(batch) != sum(BATCH_COUNTS.values()):
        errors.append(f'batch total {len(batch)}, expected {sum(BATCH_COUNTS.values())}')
    specs = {}
    for path in batch:
        try:
            info = jpeg_info(path)
        except ValueError as exc:
            errors.append(f'{path.relative_to(ROOT)}: {exc}')
            continue
        specs[info] = specs.get(info, 0) + 1
        if info[:3] != (*BATCH_SIZE, BATCH_COMPONENTS):
            errors.append(f'{path.relative_to(ROOT)}: spec {info}')

    general_ids, guest_ids, retinue_ids = registered_ids()
    coverage = [
        ('generals', general_ids, RELEASE_IMAGE),
        ('guest generals', guest_ids, GUEST_IMAGE),
        ('retinues', retinue_ids, RELEASE_IMAGE),
    ]
    for label, ids, directory in coverage:
        missing = [name for name in ids if not (ROOT / directory / f'{name}.jpg').is_file()]
        if missing:
            errors.append(f'{label}: missing {directory}/<id>.jpg for {missing}')
        print(f'coverage {label}: {len(ids) - len(missing)}/{len(ids)}')
    print(f'batch images: {len(batch)} '
          f'({BATCH_COUNTS[RELEASE_IMAGE]} ordinary + {BATCH_COUNTS[GUEST_IMAGE]} guest)')
    for (width, height, components, has_icc), count in sorted(specs.items()):
        print(f'summary {width}x{height} {components} components, '
              f'ICC {"present" if has_icc else "none"}: {count}')
    return errors


def release_sources():
    files = []
    for entry in RELEASE_ENTRIES:
        source = ROOT / entry
        if not source.exists():
            raise FileNotFoundError(source)
        files.extend([source] if source.is_file() else sorted(source.rglob('*')))
    return [path for path in files if path.is_file()]


def release_files():
    return [path for path in release_sources() if path.name != '.gitkeep']


def check_release(zip_path):
    errors = []
    expected = release_files()
    expected_names = {path.relative_to(ROOT).as_posix(): path for path in expected}
    committed = [p for p in release_sources() if p.name == '.gitkeep']
    print(f'release source files: {len(expected)}')
    if not Path(zip_path).is_file():
        return [f'missing ZIP: {zip_path}']
    import zipfile
    with zipfile.ZipFile(zip_path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            errors.append('ZIP has duplicate entries')
        entries = {}
        for name in names:
            if not name.startswith('qiao/'):
                errors.append(f'ZIP path outside qiao/: {name}')
                continue
            relative = name[len('qiao/'):]
            if relative.startswith('/') or '..' in relative.split('/'):
                errors.append(f'unsafe ZIP path: {name}')
                continue
            entries[relative] = name
        missing = sorted(set(expected_names) - set(entries))
        extra = sorted(set(entries) - set(expected_names))
        if missing:
            errors.append(f'ZIP missing {len(missing)} files: {missing[:5]}')
        if extra:
            errors.append(f'ZIP has {len(extra)} unexpected files: {extra[:5]}')
        mismatched = [relative for relative in sorted(set(expected_names) & set(entries))
                      if digest(expected_names[relative]) != digest_from_zip(archive, entries[relative])]
        if mismatched:
            errors.append(f'{len(mismatched)} byte mismatches: {mismatched[:5]}')
        images = [relative for relative in entries if relative.startswith('image/')]
        batch = [relative for relative in images
                 if relative.startswith('image/generals/') and relative.endswith('.jpg')]
        guest = [relative for relative in batch if relative.startswith('image/generals/guest/')]
        forbidden = [relative for relative in entries
                     if relative.endswith('.gitkeep') or relative.split('/')[0] in ('tests', 'scripts', '.dev')]
        if forbidden:
            errors.append(f'development entries in ZIP: {forbidden[:5]}')
        print(f'ZIP entries: {len(entries)}; image entries: {len(images)}; '
              f'batch JPEG: {len(batch)} (guest {len(guest)})')
        print(f'paths equal: {not missing and not extra}; '
              f'bytes equal: {len(expected_names) - len(mismatched)}/{len(expected_names)}')
        print(f'source .gitkeep excluded: {len(committed)}')
    return errors


def digest_from_zip(archive, name):
    value = hashlib.sha256()
    with archive.open(name) as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b''):
            value.update(chunk)
    return value.hexdigest()


def check_sync(destination):
    errors = []
    destination = Path(destination)
    expected = release_files()
    expected_names = {path.relative_to(ROOT).as_posix(): path for path in expected}
    found = [path for path in destination.rglob('*') if path.is_file()]
    found_names = {path.relative_to(destination).as_posix(): path for path in found}
    missing = sorted(set(expected_names) - set(found_names))
    extra = sorted(set(found_names) - set(expected_names))
    if missing:
        errors.append(f'sync missing {len(missing)} files: {missing[:5]}')
    if extra:
        errors.append(f'sync has {len(extra)} unexpected files: {extra[:5]}')
    nested = [name for name in found_names if any(
        left == right for left, right in zip(name.split('/'), name.split('/')[1:]))]
    if nested:
        errors.append(f'nested paths: {nested[:5]}')
    if (destination / 'pkg/pkg').exists():
        errors.append('pkg/pkg exists')
    mismatched = [name for name in sorted(set(expected_names) & set(found_names))
                  if digest(expected_names[name]) != digest(found_names[name])]
    if mismatched:
        errors.append(f'{len(mismatched)} byte mismatches: {mismatched[:5]}')
    print(f'sync destination: {destination}')
    print(f'sync files: {len(found_names)}/{len(expected_names)}; '
          f'bytes equal: {len(expected_names) - len(mismatched)}/{len(expected_names)}; '
          f'pkg/pkg: {(destination / "pkg/pkg").exists()}; nested: {len(nested)}')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release', nargs='?', const=str(ROOT / '.dev/dist/qiao.zip'),
                        help='check the built ZIP, default .dev/dist/qiao.zip')
    parser.add_argument('--sync', metavar='DIR', help='check a synced package directory')
    args = parser.parse_args()
    errors = []
    if args.sync:
        errors += check_sync(args.sync)
    elif args.release:
        errors += check_release(args.release)
    else:
        errors += check_assets()
    for error in errors:
        print(f'FAIL: {error}')
    print('OK' if not errors else f'{len(errors)} failure(s)')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
