"""Convert Docs/iOS-Documentation.md (a known markdown subset) to HTML for Chrome PDF printing."""
import html, os, re, struct, sys

md_path, out_path = sys.argv[1], sys.argv[2]
base = os.path.dirname(md_path)
lines = open(md_path, encoding="utf-8").read().split("\n")

def png_size(p):
    with open(p, "rb") as f:
        f.read(16)
        return struct.unpack(">II", f.read(8))

def inline(s):
    s = html.escape(s, quote=False)
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"(https://[^\s<|)]+)", r'<a href="\1">\1</a>', s)
    return s

img_re = re.compile(r"^!\[([^\]]*)\]\(([^)]+)\)$")
out, i, sec = [], 0, 0

def figure(cap, src):
    p = os.path.join(base, src)
    if not os.path.exists(p):
        return (f'<figure class="missing"><div class="ph">Screenshot to add:<br><b>{html.escape(cap)}</b>'
                f'<br><small>Save as Docs/{html.escape(src)} and rebuild</small></div></figure>')
    w, h = png_size(p) if p.endswith(".png") else (2, 1)
    cls = "portrait" if h > w else "landscape"
    return (f'<figure class="{cls}"><img src="file://{html.escape(os.path.abspath(p))}">'
            f'<figcaption>{html.escape(cap)}</figcaption></figure>')

while i < len(lines):
    ln = lines[i]
    if ln.startswith("```"):
        j = i + 1
        while not lines[j].startswith("```"):
            j += 1
        out.append("<pre>" + html.escape("\n".join(lines[i+1:j])) + "</pre>")
        i = j + 1
        continue
    if img_re.match(ln):
        figs = []
        while i < len(lines) and img_re.match(lines[i]):
            cap, src = img_re.match(lines[i]).groups()
            figs.append(figure(cap, src))
            i += 1
        out.append('<div class="row">' + "".join(figs) + "</div>")
        continue
    m = re.match(r"^(#{1,3}) (.*)$", ln)
    if m:
        lvl = len(m.group(1))
        if lvl == 1:
            out.append(f'<div class="title"><h1>{inline(m.group(2))}</h1>')
        else:
            if lvl == 2:
                sec += 1
            brk = ' class="newpage"' if lvl == 2 and "Screen captures" in m.group(2) else ""
            out.append(f"<h{lvl}{brk}>{inline(m.group(2))}</h{lvl}>")
        i += 1
        continue
    if ln.startswith("|"):
        rows = []
        while i < len(lines) and lines[i].startswith("|"):
            rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
            i += 1
        t = "<table><thead><tr>" + "".join(f"<th>{inline(c)}</th>" for c in rows[0]) + "</tr></thead><tbody>"
        for r in rows[2:]:
            t += "<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>"
        out.append(t + "</tbody></table>")
        continue
    if re.match(r"^(\s*)([-*]|\d+\.) ", ln):
        items = []
        while i < len(lines) and re.match(r"^(\s*)([-*]|\d+\.) ", lines[i]):
            mm = re.match(r"^(\s*)([-*]|\d+\.) (.*)$", lines[i])
            items.append((len(mm.group(1)) // 2, mm.group(2)[-1] == ".", mm.group(3)))
            i += 1
        stack, h = [], ""
        for depth, ordered, text in items:
            while len(stack) > depth + 1:
                h += f"</li></{stack.pop()}>"
            if len(stack) == depth + 1:
                h += "</li>"
            while len(stack) < depth + 1:
                tag = "ol" if ordered else "ul"
                stack.append(tag)
                h += f"<{tag}>"
            h += f"<li>{inline(text)}"
        while stack:
            h += f"</li></{stack.pop()}>"
        out.append(h)
        continue
    if ln.strip():
        para = []
        while i < len(lines) and lines[i].strip() and not re.match(r"^(#|\||```|!\[|\s*([-*]|\d+\.) )", lines[i]):
            para.append(lines[i])
            i += 1
        p = inline(" ".join(para))
        out.append(f"<p>{p}</p>")
        # Close the title block after the subtitle paragraph.
        if len(out) == 2 and out[0].startswith('<div class="title">'):
            out.append("</div>")
        continue
    i += 1

merged = []
for el in out:
    short_table = el.startswith("<table") and el.count("<tr>") <= 7
    if merged and re.match(r"<h[23]", merged[-1]) and (short_table or not el.startswith(("<table", "<pre"))):
        merged[-1] = f'<div class="keep">{merged[-1]}{el}</div>'
    elif merged and merged[-1].startswith('<div class="keep"><h3') and merged[-1].endswith("</p></div>") and el.startswith('<div class="row">'):
        merged[-1] = merged[-1][:-6] + el + "</div>"
    else:
        merged.append(el)
out = merged

css = """
@page { size: Letter; margin: 0.6in 0.6in 0.7in; }
body { font: 10.5pt -apple-system, "Helvetica Neue", Helvetica, sans-serif; color: #1d1d1f; line-height: 1.45; }
.title { border-bottom: 3px solid #0a66c2; margin-bottom: 18px; padding-bottom: 6px; }
h1 { font-size: 22pt; margin: 0 0 4px; } .title p { font-size: 12pt; color: #555; margin: 0; }
h2 { font-size: 15pt; color: #0a66c2; border-bottom: 1px solid #ddd; padding-bottom: 3px; margin-top: 20px; }
h2.newpage, .keep:has(> h2.newpage) { break-before: page; margin-top: 0; }
.keep { break-inside: avoid; }
h3 { font-size: 12pt; margin: 16px 0 6px; break-after: avoid; }
table { border-collapse: collapse; width: 100%; margin: 8px 0 12px; font-size: 9.5pt; break-inside: auto; }
tr { break-inside: avoid; }
th, td { border: 1px solid #ccc; padding: 4px 7px; text-align: left; vertical-align: top; }
th { background: #eef3f9; }
code { font: 9pt Menlo, monospace; background: #f2f2f4; padding: 0 3px; border-radius: 3px; }
pre { font: 8.3pt/1.3 Menlo, monospace; background: #f6f8fa; border: 1px solid #e1e4e8; padding: 8px 10px; white-space: pre; }
a { color: #0a66c2; text-decoration: none; }
ul, ol { margin: 4px 0 8px; padding-left: 22px; } li { margin: 2px 0; }
.row { display: flex; gap: 14px; justify-content: center; align-items: flex-start; margin: 8px 0 14px; break-inside: avoid; }
figure { margin: 0; text-align: center; break-inside: avoid; }
figure img { border: 1px solid #ccc; border-radius: 8px; display: block; margin: 0 auto; }
figure.portrait img { height: 3.55in; }
figure.landscape { width: 100%; } figure.landscape img[src$='.svg'] { width: 100%; max-height: 4.1in; border: none; } figure.landscape img { max-width: 100%; max-height: 4.2in; }
figcaption { font-size: 9pt; color: #444; margin-top: 4px; }
figure.missing { width: 100%; } .ph { border: 2px dashed #bbb; border-radius: 8px; padding: 40px 10px; color: #888; }
"""
open(out_path, "w", encoding="utf-8").write(
    f'<!doctype html><html><head><meta charset="utf-8"><style>{css}</style></head><body>{"".join(out)}</body></html>')
