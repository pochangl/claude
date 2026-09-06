#!/usr/bin/env python3
"""Render a work-summary manifest into index.html or index.md.

Usage: build_summary.py <manifest.json> [--format html|md] [--out <path>]
Output defaults to index.<ext> next to the manifest.
"""

import argparse
import datetime
import html
import json
import os
import sys

REQUIRED_KEYS = ('title', 'range_label', 'items')

CSS = """
:root {
  color-scheme: light dark;
  --bg: #f7f7f5;
  --card: #ffffff;
  --fg: #1b1b19;
  --muted: #6b6b66;
  --line: #e2e2dd;
  --accent: #b4541e;
  --shot-min: %(shot_min)s;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #161614;
    --card: #1f1f1d;
    --fg: #ececea;
    --muted: #9b9b95;
    --line: #302f2c;
    --accent: #e08c5a;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0;
  padding: 32px 20px 64px;
  background: var(--bg);
  color: var(--fg);
  font: 15px/1.6 -apple-system, "Segoe UI", "Noto Sans TC", "PingFang TC", sans-serif;
}
main { max-width: 1080px; margin: 0 auto; }
header { border-bottom: 1px solid var(--line); padding-bottom: 20px; margin-bottom: 28px; }
h1 { margin: 0 0 8px; font-size: 26px; letter-spacing: -0.01em; }
.meta { color: var(--muted); font-size: 13px; display: flex; flex-wrap: wrap; gap: 6px 14px; }
.badge {
  border: 1px solid var(--line); border-radius: 999px;
  padding: 1px 10px; color: var(--accent);
}
.item {
  background: var(--card); border: 1px solid var(--line); border-radius: 12px;
  padding: 20px 22px; margin-bottom: 20px;
}
.item h2 { margin: 0 0 6px; font-size: 18px; }
.item p { margin: 0 0 14px; color: var(--fg); }
details { margin-top: 12px; }
summary { cursor: pointer; color: var(--muted); font-size: 13px; }
.commits { margin: 8px 0 0; padding-left: 18px; color: var(--muted); font-size: 12.5px; }
.commits li { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
.shots {
  display: grid; gap: 14px;
  grid-template-columns: repeat(auto-fill, minmax(var(--shot-min), 1fr));
}
figure { margin: 0; }
figure img {
  width: 100%%; display: block; border: 1px solid var(--line);
  border-radius: 8px; background: var(--bg);
}
figcaption { margin-top: 6px; color: var(--muted); font-size: 12.5px; }
.other { color: var(--muted); font-size: 13.5px; }
.other li { margin-bottom: 4px; }
footer { margin-top: 36px; color: var(--muted); font-size: 12px; }
"""


def load_manifest(path):
    with open(path, encoding='utf-8') as handle:
        manifest = json.load(handle)
    missing = [key for key in REQUIRED_KEYS if key not in manifest]
    if missing:
        raise ValueError(f'manifest {path} is missing keys: {", ".join(missing)}')
    if not isinstance(manifest['items'], list):
        raise ValueError(f'manifest {path}: "items" must be a list')
    return manifest


def render_html(manifest):
    esc = html.escape
    shot_min = '420px' if manifest.get('platform') == 'web' else '240px'
    parts = [
        '<!DOCTYPE html>',
        '<html lang="zh-Hant">',
        '<head>',
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        f'<title>{esc(manifest["title"])}</title>',
        f'<style>{CSS % {"shot_min": shot_min}}</style>',
        '</head>',
        '<body>',
        '<main>',
        '<header>',
        f'<h1>{esc(manifest["title"])}</h1>',
        '<div class="meta">',
        f'<span class="badge">{esc(manifest["range_label"])}</span>',
    ]
    if manifest.get('project'):
        parts.append(f'<span>{esc(manifest["project"])}</span>')
    if manifest.get('platform'):
        parts.append(f'<span>{esc(manifest["platform"])}</span>')
    parts += ['</div>', '</header>']

    for item in manifest['items']:
        parts.append('<section class="item">')
        parts.append(f'<h2>{esc(item.get("title", ""))}</h2>')
        if item.get('description'):
            parts.append(f'<p>{esc(item["description"])}</p>')
        shots = item.get('screenshots') or []
        if shots:
            parts.append('<div class="shots">')
            for shot in shots:
                src = esc(shot['file'])
                parts.append(f'<figure><a href="{src}" target="_blank" rel="noopener">'
                             f'<img src="{src}" alt="{esc(shot.get("caption", ""))}" loading="lazy">'
                             '</a>')
                if shot.get('caption'):
                    parts.append(f'<figcaption>{esc(shot["caption"])}</figcaption>')
                parts.append('</figure>')
            parts.append('</div>')
        commits = item.get('commits') or []
        if commits:
            parts.append(f'<details><summary>{len(commits)} commits</summary><ul class="commits">')
            parts += [f'<li>{esc(line)}</li>' for line in commits]
            parts.append('</ul></details>')
        parts.append('</section>')

    others = manifest.get('other_changes') or []
    if others:
        parts.append('<section class="item"><h2>其他變更</h2><ul class="other">')
        parts += [f'<li>{esc(line)}</li>' for line in others]
        parts.append('</ul></section>')

    parts.append(f'<footer>Generated {esc(manifest["generated_at"])}</footer>')
    parts += ['</main>', '</body>', '</html>']
    return '\n'.join(parts)


def render_md(manifest):
    lines = [f'# {manifest["title"]}', '', f'{manifest["range_label"]}']
    if manifest.get('project'):
        lines.append(f'Project: {manifest["project"]}')
    lines.append('')
    for item in manifest['items']:
        lines += [f'## {item.get("title", "")}', '']
        if item.get('description'):
            lines += [item['description'], '']
        for shot in item.get('screenshots') or []:
            lines.append(f'![{shot.get("caption", "")}]({shot["file"]})')
            if shot.get('caption'):
                lines.append(f'*{shot["caption"]}*')
            lines.append('')
        for line in item.get('commits') or []:
            lines.append(f'- `{line}`')
        lines.append('')
    others = manifest.get('other_changes') or []
    if others:
        lines += ['## 其他變更', '']
        lines += [f'- {line}' for line in others]
        lines.append('')
    lines.append(f'_Generated {manifest["generated_at"]}_')
    return '\n'.join(lines)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest')
    parser.add_argument('--format', choices=('html', 'md'), default='html')
    parser.add_argument('--out')
    args = parser.parse_args(argv)

    manifest = load_manifest(args.manifest)
    manifest.setdefault('generated_at', datetime.datetime.now().strftime('%Y-%m-%d %H:%M'))

    out = args.out or os.path.join(os.path.dirname(os.path.abspath(args.manifest)),
                                   f'index.{args.format}')
    body = render_html(manifest) if args.format == 'html' else render_md(manifest)
    with open(out, 'w', encoding='utf-8') as handle:
        handle.write(body)
    print(out)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
