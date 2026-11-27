#!/usr/bin/env python3
"""Keep every screenshot taken while working, so a later work summary can use
them. The one place that knows where they live and how they are named:

    <project root>/summarize/screenshots/<YYYY-MM-DD>/<HHMMSS>-<name>.png

Usage:
    shot.py <name> [device]     capture the Android screen (adb exec-out screencap)
    shot.py --path <name>       only print the next free path (for Playwright etc.)
    shot.py --dir [YYYY-MM-DD]  print the day's folder (default today)

Runs on Linux, macOS and Windows. Date and time are Taipei time. The project
root is the git top level of the current directory, else the current
directory. Never overwrites: a clash gets a -2, -3 ... suffix. Exits 1 on a bad
capture, which stays on disk for inspection.
"""
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Taipei has no DST, so a fixed offset avoids needing tzdata on Windows.
TAIPEI = timezone(timedelta(hours=8), 'Asia/Taipei')
MIN_PNG_BYTES = 10 * 1024
PNG_MAGIC = b'\x89PNG'

ANDROID_SDK = os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
LOCALAPPDATA = os.environ.get('LOCALAPPDATA', '')


def project_root() -> Path:
    try:
        out = subprocess.run(['git', 'rev-parse', '--show-toplevel'],
                             capture_output=True, text=True, check=True)
        return Path(out.stdout.strip())
    except (OSError, subprocess.CalledProcessError):
        return Path.cwd()


def find_adb() -> str:
    exe = 'adb.exe' if os.name == 'nt' else 'adb'
    candidates = [Path(ANDROID_SDK)] if ANDROID_SDK else []
    candidates += [Path(LOCALAPPDATA) / 'Android' / 'Sdk',      # Windows
                   Path.home() / 'Library' / 'Android' / 'sdk',  # macOS
                   Path.home() / 'Android' / 'Sdk']              # Linux
    for sdk in candidates:
        adb = sdk / 'platform-tools' / exe
        if adb.is_file():
            return str(adb)
    on_path = shutil.which('adb')
    if on_path:
        return on_path
    raise FileNotFoundError('adb not found: set ANDROID_HOME or put adb on PATH')


def day_dir(day: str | None = None) -> Path:
    day = day or datetime.now(TAIPEI).strftime('%Y-%m-%d')
    return project_root() / 'summarize' / 'screenshots' / day


def next_path(name: str) -> Path:
    """Create the day's folder (and summarize/.gitignore) and return a free path."""
    folder = day_dir()
    folder.mkdir(parents=True, exist_ok=True)
    gitignore = folder.parent.parent / '.gitignore'
    if not gitignore.exists():
        gitignore.write_text('*\n')
    slug = re.sub(r'[\s/\\:*?"<>|]+', '-', name).strip('-')
    base = f'{datetime.now(TAIPEI).strftime("%H%M%S")}-{slug}'
    path, n = folder / f'{base}.png', 2
    while path.exists():
        path, n = folder / f'{base}-{n}.png', n + 1
    return path


def capture(name: str, device: str | None) -> Path:
    path = next_path(name)
    cmd = [find_adb()] + (['-s', device] if device else []) + ['exec-out', 'screencap', '-p']
    # Read adb's stdout as bytes: a shell redirect (PowerShell `>`) corrupts the PNG.
    result = subprocess.run(cmd, capture_output=True)
    data = result.stdout
    if result.returncode != 0 or not data:
        raise RuntimeError(f'adb failed ({result.returncode}): '
                           f'{result.stderr.decode(errors="replace").strip()}')
    path.write_bytes(data)
    if not data.startswith(PNG_MAGIC) or len(data) < MIN_PNG_BYTES:
        raise RuntimeError(f'bad capture ({len(data)} bytes), kept for inspection: {path}')
    return path


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ('-h', '--help'):
        print(__doc__)
        return 2
    if argv[0] == '--dir':
        print(day_dir(argv[1] if len(argv) > 1 else None))
        return 0
    if argv[0] == '--path':
        if len(argv) < 2:
            print(__doc__)
            return 2
        print(next_path(argv[1]))
        return 0
    try:
        print(capture(argv[0], argv[1] if len(argv) > 1 else None))
    except (RuntimeError, FileNotFoundError) as e:
        print(e, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
