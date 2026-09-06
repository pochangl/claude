#!/usr/bin/env python3
"""Print the centre coordinates of a uiautomator node, for `adb shell input tap`.

Usage: ui_center.py <ui.xml> (--text T | --id I | --desc D)
Matching is substring-based; exits 1 when nothing matches.
"""

import argparse
import re
import sys
import xml.etree.ElementTree as ET

BOUNDS_RE = re.compile(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]')


def find_center(xml_path, attribute, needle):
    root = ET.parse(xml_path).getroot()
    for node in root.iter('node'):
        if needle not in node.get(attribute, ''):
            continue
        match = BOUNDS_RE.match(node.get('bounds', ''))
        if not match:
            continue
        left, top, right, bottom = (int(value) for value in match.groups())
        return (left + right) // 2, (top + bottom) // 2
    raise LookupError(f'no node with {attribute} containing {needle!r} in {xml_path}')


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('xml')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--text')
    group.add_argument('--id')
    group.add_argument('--desc')
    args = parser.parse_args(argv)

    attribute, needle = ('text', args.text) if args.text else \
        ('resource-id', args.id) if args.id else ('content-desc', args.desc)
    try:
        x, y = find_center(args.xml, attribute, needle)
    except LookupError as error:
        print(error, file=sys.stderr)
        return 1
    print(f'{x} {y}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
