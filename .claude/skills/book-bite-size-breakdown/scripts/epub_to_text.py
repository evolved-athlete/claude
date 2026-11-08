"""Extract an EPUB to plain text, keeping lists, tables and image markers.

Usage: python3 -I epub_to_text.py BOOK.epub OUT.txt

Many ebook-to-text converters drop bulleted and numbered lists, which is where
books keep their protocols and recipe directions. This keeps every list item on
its own line and marks images with [IMG] so missing content is visible.
"""
import html
import re
import sys
import zipfile


def spine_order(z):
    opf_name = next(n for n in z.namelist() if n.endswith('.opf'))
    opf = z.read(opf_name).decode('utf8', 'ignore')
    manifest = {}
    for item in re.findall(r'<item\b[^>]*>', opf):
        item_id = re.search(r'\bid="([^"]+)"', item)
        href = re.search(r'\bhref="([^"]+)"', item)
        if item_id and href:
            manifest[item_id.group(1)] = href.group(1)
    base = opf_name.rsplit('/', 1)[0] + '/' if '/' in opf_name else ''
    order = [base + manifest[i] for i in re.findall(r'<itemref\b[^>]*idref="([^"]+)"', opf) if i in manifest]
    return order or [n for n in z.namelist() if n.endswith(('.html', '.xhtml', '.htm'))]


def to_text(markup):
    t = re.sub(r'(?s)<head.*?</head>', '', markup)
    t = re.sub(r'<li[^>]*>', '\n- ', t)
    t = re.sub(r'<img[^>]*>', '[IMG]', t)
    t = re.sub(r'<(td|th)[^>]*>', ' | ', t)
    t = re.sub(r'</(p|div|h\d|li|tr|table|ul|ol)>', '\n', t)
    t = re.sub(r'<br\s*/?>', '\n', t)
    t = re.sub(r'<[^>]+>', '', t)
    t = html.unescape(t)
    # Inline bullets ("Signs:• one• two") onto their own lines.
    t = re.sub(r'\s*•\s*', '\n- ', t)
    # Run-together numbered steps ("Mix well.2. Bake") onto their own lines.
    t = re.sub(r'(?<=[.!?)"”])\s*(\d{1,2})\.\s+(?=[A-Z])', r'\n\1. ', t)
    return t


def main(src, dst):
    z = zipfile.ZipFile(src)
    parts = []
    for name in spine_order(z):
        try:
            parts.append(to_text(z.read(name).decode('utf8', 'ignore')))
        except KeyError:
            continue
    text = re.sub(r'\n[ \t]*\n+', '\n', '\n'.join(parts))
    with open(dst, 'w') as f:
        f.write(text)
    lines = text.count('\n')
    items = len(re.findall(r'^(- |\d{1,2}\. )', text, flags=re.M))
    images = text.count('[IMG]')
    print(f'{lines} lines, {items} list items, {images} images -> {dst}')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
