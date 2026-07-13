from pathlib import Path
import re
root = Path('..').resolve()
html_files = list(root.glob('*.html')) + list(root.glob('owner/*.html')) + list(root.glob('worker/*.html'))
pattern = re.compile(r'<!-- Tailwind CSS -->\s*\n\s*<script src="https://cdn\.tailwindcss\.com"></script>\s*\n\s*<script>.*?</script>', re.S)
new_root = '  <!-- Tailwind CSS -->\n  <script src="assets/js/tailwind-config.js"></script>\n  <script src="https://cdn.tailwindcss.com"></script>'
new_sub = '  <!-- Tailwind CSS -->\n  <script src="../assets/js/tailwind-config.js"></script>\n  <script src="https://cdn.tailwindcss.com"></script>'
changed = 0
bad = []
for f in html_files:
    text = f.read_text(encoding='utf-8')
    if 'tailwind.config' not in text:
        continue
    replacement = new_root if f.parent.resolve() == root else new_sub
    new_text, count = pattern.subn(replacement, text)
    if count == 1:
        f.write_text(new_text, encoding='utf-8')
        changed += 1
    else:
        bad.append((str(f), count))
print('changed', changed)
for b in bad:
    print('bad', b)
