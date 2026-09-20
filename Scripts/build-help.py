#!/usr/bin/env python3
"""Builds the Mac app's Apple Help Book, Help/ChitarraTune.help, from the user guide in docs/guide.

The guide is written once, in Markdown, in English (docs/guide/en) and Italian (docs/guide/it): it
reads on GitHub for iPhone and iPad users, and this script turns it into the Help Book that the
Help menu opens in the Mac's Help Viewer, with the table of contents, light and dark appearance, and
the Core Spotlight search index Apple's Help Viewer uses (hiutil).

    Scripts/build-help.py            rebuild Help/ChitarraTune.help
    Scripts/build-help.py --check    fail if Help/ChitarraTune.help is not what the guide produces

Only a small Markdown subset is understood (headings, paragraphs, bold, italic, code, links, lists,
numbered steps with indented notes, tables, "> " notes, and a first-line description comment), and
anything else is an error: the guide must stay simple enough to translate. Nothing in the book
loads from the network (ADR 0003): no remote images, fonts, scripts or knowledge-base URL.
"""

import html
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUIDE = os.path.join(ROOT, "docs", "guide")
BOOK = os.path.join(ROOT, "Help", "ChitarraTune.help")
BUNDLE_ID = "com.chitarratune.app.help"

# Page order of the table of contents; every language has exactly these pages.
PAGES = ["index", "tune", "read-display", "pin-string", "tunings", "reference-pitch", "input", "windows",
         "settings", "siri-shortcuts", "keyboard", "accessibility", "accurate-tuning", "troubleshooting", "privacy"]

LANGUAGES = {
    "en": {"book": "ChitarraTune Help", "contents": "Contents", "copyright": "© 2025–2026 ChitarraTune contributors.",
           "home": "ChitarraTune User Guide"},
    "it": {"book": "Aiuto di ChitarraTune", "contents": "Sommario", "copyright": "© 2025–2026 ChitarraTune contributors.",
           "home": "Manuale utente di ChitarraTune"},
}


class GuideError(Exception):
    pass


def inline(text):
    """Escapes `text` and renders code, bold, italic and links."""
    out, pos = [], 0
    pattern = re.compile(r"`([^`]+)`|\*\*(.+?)\*\*|\*(.+?)\*|\[([^\]]+)\]\(([^)\s]+)\)")
    for match in pattern.finditer(text):
        out.append(html.escape(text[pos:match.start()], quote=False))
        code, bold, italic, label, target = match.groups()
        if code is not None:
            out.append(f"<code>{html.escape(code, quote=False)}</code>")
        elif bold is not None:
            out.append(f"<strong>{inline(bold)}</strong>")
        elif italic is not None:
            out.append(f"<em>{inline(italic)}</em>")
        else:
            if target.startswith(("http:", "https:", "//")):
                raise GuideError(f"external link {target!r}: the Help Book stays offline")
            if target.endswith(".md"):
                target = target[:-3] + ".html"   # the guide links page to page in Markdown, the book in HTML
            out.append(f'<a href="{html.escape(target)}">{inline(label)}</a>')
        pos = match.end()
    out.append(html.escape(text[pos:], quote=False))
    return "".join(out)


def convert(markdown, name):
    """Returns (title, description, body HTML) for one page."""
    lines = markdown.rstrip("\n").split("\n")
    if not lines[0].startswith("# "):
        raise GuideError(f"{name}: the first line must be the '# ' title")
    title = lines[0][2:].strip()
    description = ""
    index = 1
    if index < len(lines) and (m := re.fullmatch(r"<!-- description: (.+) -->", lines[index].strip())):
        description = m.group(1)
        index += 1
    if not description:
        raise GuideError(f"{name}: a '<!-- description: … -->' line must follow the title")

    body, i = [], index
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
        elif line.startswith("## "):
            heading = line[3:].strip()
            anchor = re.sub(r"[^a-z0-9]+", "-", heading.lower()).strip("-")
            body.append(f'<h2 id="{anchor}">{inline(heading)}</h2>')
            i += 1
        elif line.startswith("> "):
            quote = []
            while i < len(lines) and lines[i].startswith("> "):
                quote.append(lines[i][2:])
                i += 1
            body.append(f'<aside class="note"><p>{inline(" ".join(quote))}</p></aside>')
        elif line.startswith("| "):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                rows.append([cell.strip() for cell in lines[i].strip().strip("|").split("|")])
                i += 1
            if len(rows) < 2 or not all(re.fullmatch(r":?-+:?", c) for c in rows[1]):
                raise GuideError(f"{name}: a table needs a header and a separator row")
            head = "".join(f"<th>{inline(c)}</th>" for c in rows[0])
            rest = "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in row) + "</tr>" for row in rows[2:])
            body.append(f"<table><thead><tr>{head}</tr></thead><tbody>{rest}</tbody></table>")
        elif re.match(r"(- |\d+\. )", line):
            ordered = bool(re.match(r"\d+\. ", line))
            items = []
            while i < len(lines) and (re.match(r"(- |\d+\. )", lines[i]) or lines[i].startswith("   ") or not lines[i].strip()):
                current = lines[i]
                if re.match(r"(- |\d+\. )", current) and (bool(re.match(r"\d+\. ", current)) == ordered):
                    items.append([re.sub(r"^(- |\d+\. )", "", current)])
                elif current.startswith("   ") and items:
                    items[-1].append(current[3:])
                elif not current.strip():
                    if i + 1 < len(lines) and (lines[i + 1].startswith("   ") or re.match(r"(- |\d+\. )", lines[i + 1])):
                        items[-1].append("")
                    else:
                        break
                else:
                    break
                i += 1
            rendered = []
            for item in items:
                blocks = "\n".join(item).split("\n\n")
                parts = []
                for block in blocks:
                    block = block.strip()
                    if not block:
                        continue
                    if block.startswith("- "):
                        sub = "".join(f"<li>{inline(b[2:])}</li>" for b in block.split("\n"))
                        parts.append(f"<ul>{sub}</ul>")
                    else:
                        parts.append(f"<p>{inline(' '.join(block.split(chr(10))))}</p>")
                rendered.append("<li>" + "".join(parts) + "</li>")
            tag = "ol" if ordered else "ul"
            body.append(f"<{tag}>" + "".join(rendered) + f"</{tag}>")
        elif line.startswith(("#", "<", "```", "    ")):
            raise GuideError(f"{name}: unsupported Markdown: {line!r}")
        else:
            paragraph = []
            while i < len(lines) and lines[i].strip() and not re.match(r"(#|> |\| |- |\d+\. )", lines[i]):
                paragraph.append(lines[i].strip())
                i += 1
            body.append(f"<p>{inline(' '.join(paragraph))}</p>")
    return title, description, "\n".join(body)


def page_html(language, slug, title, description, body, toc):
    strings = LANGUAGES[language]
    is_home = slug == "index"
    current = ' class="current" aria-current="page"'
    items = "\n".join(
        f'<li{current if s == slug else ""}><a href="{s}.html">{html.escape(t)}</a></li>'
        for s, t in toc
    )
    apple = (f'<meta name="AppleTitle" content="{html.escape(strings["book"])}">\n'
             f'<meta name="AppleIcon" content="../Shared/icon.png">\n') if is_home else ""
    return f"""<!DOCTYPE html>
<html lang="{language}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
{apple}<meta name="description" content="{html.escape(description)}">
<meta name="robots" content="anchors">
<title>{html.escape(title)}</title>
<link rel="stylesheet" href="../Shared/guide.css">
</head>
<body class="{'home' if is_home else 'topic'}">
<a name="{slug}"></a>
<header><a href="index.html"><img src="../Shared/icon.png" alt="" width="32" height="32"><span>{html.escape(strings["home"])}</span></a></header>
<div class="layout">
<nav aria-label="{html.escape(strings["contents"])}"><h2>{html.escape(strings["contents"])}</h2><ol>
{items}
</ol></nav>
<main>
<h1>{html.escape(title)}</h1>
{body}
</main>
</div>
<footer>{html.escape(strings["copyright"])}</footer>
</body>
</html>
"""


def build(destination):
    resources = os.path.join(destination, "Contents", "Resources")
    shared = os.path.join(resources, "Shared")
    os.makedirs(shared)
    shutil.copyfile(os.path.join(GUIDE, "guide.css"), os.path.join(shared, "guide.css"))
    shutil.copyfile(os.path.join(ROOT, "docs", "assets", "icon.png"), os.path.join(shared, "icon.png"))

    for language, strings in LANGUAGES.items():
        folder = os.path.join(GUIDE, language)
        found = sorted(f[:-3] for f in os.listdir(folder) if f.endswith(".md"))
        if found != sorted(PAGES):
            raise GuideError(f"{language}: pages {found} are not exactly {sorted(PAGES)}")
        pages = {}
        for slug in PAGES:
            with open(os.path.join(folder, slug + ".md"), encoding="utf-8") as handle:
                pages[slug] = convert(handle.read(), f"{language}/{slug}.md")
        toc = [(slug, pages[slug][0]) for slug in PAGES]
        lproj = os.path.join(resources, f"{language}.lproj")
        os.makedirs(lproj)
        for slug, (title, description, body) in pages.items():
            for target in re.findall(r'href="([^"#]+)', body):
                if target.endswith(".html") and target[:-5] not in PAGES:
                    raise GuideError(f"{language}/{slug}.md links to {target}, which is not a page")
            with open(os.path.join(lproj, slug + ".html"), "w", encoding="utf-8") as handle:
                handle.write(page_html(language, slug, title, description, body, toc))
        with open(os.path.join(lproj, "InfoPlist.strings"), "w", encoding="utf-8") as handle:
            handle.write(f'HPDBookTitle = "{strings["book"]}";\nCFBundleName = "{strings["book"]}";\n')

    info = {
        "CFBundleDevelopmentRegion": "en",
        "CFBundleIdentifier": BUNDLE_ID,
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": LANGUAGES["en"]["book"],
        "CFBundlePackageType": "BNDL",
        "CFBundleShortVersionString": "1",
        "CFBundleSignature": "hbwr",
        "CFBundleVersion": "1",
        "HPDBookAccessPath": "index.html",
        "HPDBookIconPath": "Shared/icon.png",
        "HPDBookIndexPath": "ChitarraTune.cshelpindex",
        "HPDBookTitle": LANGUAGES["en"]["book"],
        "HPDBookType": "3",
    }
    with open(os.path.join(destination, "Contents", "Info.plist"), "wb") as handle:
        plistlib.dump(info, handle, sort_keys=True)


def index(destination):
    """The Core Spotlight search index Help Viewer uses, one per language."""
    for language in LANGUAGES:
        lproj = os.path.join(destination, "Contents", "Resources", f"{language}.lproj")
        subprocess.run(["hiutil", "-I", "corespotlight", "-C", "-a", "-s", language, "-l", language,
                        "-f", os.path.join(lproj, "ChitarraTune.cshelpindex"), lproj],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def tree(path):
    """Every file under `path` except the search indexes, with its bytes."""
    files = {}
    for folder, _, names in os.walk(path):
        for name in names:
            if name.endswith(".cshelpindex") or name == ".DS_Store":
                continue
            full = os.path.join(folder, name)
            with open(full, "rb") as handle:
                files[os.path.relpath(full, path)] = handle.read()
    return files


def main():
    check = sys.argv[1:] == ["--check"]
    if sys.argv[1:] not in ([], ["--check"]):
        sys.exit(__doc__)
    try:
        with tempfile.TemporaryDirectory() as scratch:
            fresh = os.path.join(scratch, "ChitarraTune.help")
            build(fresh)
            if check:
                if tree(fresh) != tree(BOOK):
                    sys.exit("error: Help/ChitarraTune.help is out of date: run Scripts/build-help.py")
                for language in LANGUAGES:
                    idx = os.path.join(BOOK, "Contents", "Resources", f"{language}.lproj", "ChitarraTune.cshelpindex")
                    if not os.path.isfile(idx) or os.path.getsize(idx) == 0:
                        sys.exit(f"error: the {language} search index is missing: run Scripts/build-help.py")
                print("Help/ChitarraTune.help matches docs/guide")
                return
            index(fresh)
            shutil.rmtree(BOOK, ignore_errors=True)
            os.makedirs(os.path.dirname(BOOK), exist_ok=True)
            shutil.copytree(fresh, BOOK)
            print(f"built {os.path.relpath(BOOK, ROOT)}: {len(PAGES)} pages in {', '.join(LANGUAGES)}")
    except GuideError as error:
        sys.exit(f"error: {error}")


if __name__ == "__main__":
    main()
