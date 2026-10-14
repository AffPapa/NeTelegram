#!/usr/bin/env python3
"""Render NeTelegram's prebuilt, no-JavaScript public pages from shared shell + content."""
from html import escape
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DIST = ROOT / "dist"
NAV = [
    ("features", "/features/", "Возможности"),
    ("downloads", "/downloads/", "Загрузки"),
    ("changelog", "/changelog/", "Релизы"),
    ("devlog", "/devlog/", "Разработка"),
    ("roadmap", "/roadmap/", "План"),
    ("privacy", "/privacy/", "Приватность"),
    ("source", "/source/", "Исходники"),
]
SHELL = '''<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light">
  <meta name="theme-color" content="#ffffff">
  <meta name="description" content="{description}">
  <meta property="og:title" content="{title}">
  <meta property="og:description" content="{description}">
  <meta property="og:type" content="website">
  <link rel="canonical" href="https://netelegram.iryadom.chatgpt.site{route}">
  <title>{title}</title>
  <link rel="icon" type="image/svg+xml" href="/favicon.svg">
  <link rel="stylesheet" href="/site.css">
</head>
<body class="{body_class}">
  <a class="skip-link" href="#main">К основному содержимому</a>
  <header class="topbar">
    <a class="wordmark" href="/" aria-label="NeTelegram — главная"{home_current}><span class="mark" aria-hidden="true">A</span><span>NeTelegram</span></a>
    <nav class="desktop-nav" aria-label="Основная навигация">{desktop_nav}<a class="language-link" href="/#english" lang="en">EN</a></nav>
    <details class="mobile-nav"><summary aria-label="Открыть меню"><span></span><span></span><span></span></summary><nav aria-label="Мобильная навигация">{mobile_nav}<a href="/#english" lang="en">English overview</a></nav></details>
  </header>
  <main id="main" class="page-main">{content}</main>
  <footer class="site-footer">
    <a class="wordmark" href="/" aria-label="NeTelegram — главная"><span class="mark" aria-hidden="true">A</span><span>NeTelegram</span></a>
    <p>NeTelegram — независимое приложение на основе Telegram API и часть экосистемы Telegram. Оно не является официальным клиентом и не имеет прямого отношения к Telegram Messenger LLP. Проект в разработке; проверенной сборки пока нет.</p>
    <nav aria-label="Информация"><a href="/privacy/">Приватность</a><a href="/source/">Исходники и поддержка</a><a href="/downloads/">Статус загрузок</a></nav>
  </footer>
</body>
</html>
'''

def nav_links(active):
    return "".join('<a href="{}"{}>{}</a>'.format(url, ' aria-current="page"' if key == active else "", label) for key, url, label in NAV)

for meta_path in sorted((ROOT / "content").glob("*.json")):
    meta = json.loads(meta_path.read_text())
    name = meta_path.stem
    body = (ROOT / "content" / f"{name}.html").read_text().strip()
    html = SHELL.format(
        description=escape(meta["description"], quote=True),
        title=escape(meta["title"], quote=True),
        route=meta["route"], body_class=meta["body_class"], content=body,
        desktop_nav=nav_links(name), mobile_nav=nav_links(name),
        home_current=' aria-current="page"' if name == "index" else "",
    )
    output = DIST / ("index.html" if name == "index" else f"{name}/index.html")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(html)
shutil.copyfile(ROOT / "site.css", DIST / "site.css")
print(f"Rendered {len(list((ROOT / 'content').glob('*.json')))} static routes into dist/.")
