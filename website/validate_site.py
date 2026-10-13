#!/usr/bin/env python3
"""Focused static-site checks for NeTelegram's shared-shell build."""
from html.parser import HTMLParser
from pathlib import Path

ROUTES = ["index", "features", "downloads", "changelog", "devlog", "roadmap", "privacy", "source"]
class Page(HTMLParser):
    def __init__(self):
        super().__init__(); self.h1=0; self.nav=0; self.main=0; self.footer=0; self.head=False; self.head_title=0; self.canonical=0; self.lang=None; self.links=[]
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if tag == "html": self.lang=a.get("lang")
        if tag == "head": self.head=True
        if tag == "nav": self.nav+=1
        if tag == "main": self.main+=1
        if tag == "footer": self.footer+=1
        if tag == "h1": self.h1+=1
        if tag == "title" and self.head: self.head_title+=1
        if tag == "link" and a.get("rel")=="canonical": self.canonical+=1
        if tag == "a" and a.get("href"): self.links.append(a["href"])
    def handle_endtag(self, tag):
        if tag == "head": self.head=False

errors=[]
for name in ROUTES:
    file=Path("dist/index.html") if name=="index" else Path("dist")/name/"index.html"
    parser=Page(); parser.feed(file.read_text())
    if parser.lang!="ru": errors.append(f"{name}: expected lang=ru")
    if (parser.h1,parser.nav,parser.main,parser.footer,parser.head_title,parser.canonical)!=(1,3,1,1,1,1):
        errors.append(f"{name}: shell counts h1/nav/main/footer/title/canonical={(parser.h1,parser.nav,parser.main,parser.footer,parser.head_title,parser.canonical)}")
    if "aria-current=\"page\"" not in file.read_text(): errors.append(f"{name}: missing active navigation marker")
    for href in parser.links:
        if not href.startswith("/") or href.startswith("//"): continue
        path,_,fragment=href.partition("#")
        if path in ("", "/"): target=Path("dist/index.html")
        else:
            target=Path("dist")/path.lstrip("/")
            if path.endswith("/"): target=target/"index.html"
        if not target.exists(): errors.append(f"{name}: broken local link {href}")
        elif fragment and target.suffix==".html" and fragment not in target.read_text(): errors.append(f"{name}: missing fragment {href}")
if not Path("dist/site.css").exists() or not Path("dist/favicon.svg").exists(): errors.append("shared CSS or favicon missing")
if errors:
    print("\n".join(errors)); raise SystemExit(1)
print(f"PASS: {len(ROUTES)} static routes, shared shell, active navigation, canonical metadata, local links and assets.")
