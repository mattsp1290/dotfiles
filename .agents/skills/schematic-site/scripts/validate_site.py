#!/usr/bin/env python3
"""Validate the portable structure and component links of a schematic site."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


DANGEROUS_LINK_SCHEMES = {"blob", "data", "file", "javascript", "vbscript"}
ALLOWED_SUFFIXES = {
    ".css", ".gif", ".htm", ".html", ".ico", ".jpeg", ".jpg", ".js",
    ".json", ".pdf", ".png", ".svg", ".txt", ".webp",
}
SECRET_ASSIGNMENT = re.compile(
    r"(?i)\b(?:api[_-]?key|access[_-]?token|auth[_-]?token|password|passwd|"
    r"private[_-]?key|client[_-]?secret)\b['\"]?\s*[:=]\s*['\"]?[A-Za-z0-9_+/=-]{8,}"
)
PRIVATE_KEY_HEADER = re.compile(
    r"-----BEGIN (?:OPENSSH |RSA |EC |DSA |PGP )?PRIVATE KEY-----"
)


@dataclass
class ComponentLink:
    href: str
    label: str
    line: int
    in_svg: bool
    refs: list[tuple[str, int]] = field(default_factory=list)


@dataclass
class Page:
    path: Path
    title: bool = False
    lang: str = ""
    main_count: int = 0
    ids: list[str] = field(default_factory=list)
    links: list[tuple[str, int]] = field(default_factory=list)
    assets: list[tuple[str, str, int]] = field(default_factory=list)
    component_links: list[ComponentLink] = field(default_factory=list)
    detached_refs: list[tuple[str, int]] = field(default_factory=list)
    component_page_refs: list[str] = field(default_factory=list)
    inline_handlers: list[tuple[str, int]] = field(default_factory=list)


class PageParser(HTMLParser):
    def __init__(self, path: Path) -> None:
        super().__init__(convert_charrefs=True)
        self.page = Page(path)
        self._in_title = False
        self._tags: list[str] = []
        self._component_stack: list[ComponentLink] = []

    def handle_starttag(self, tag: str, attrs_list: list[tuple[str, str | None]]) -> None:
        attrs = {key: value or "" for key, value in attrs_list}
        line, _ = self.getpos()
        classes = set(attrs.get("class", "").split())

        if tag == "html":
            self.page.lang = attrs.get("lang", "")
        elif tag == "title":
            self._in_title = True
        elif tag == "main":
            self.page.main_count += 1

        if attrs.get("id"):
            self.page.ids.append(attrs["id"])
        if attrs.get("data-component-page"):
            self.page.component_page_refs.extend(
                item.upper()
                for item in re.split(r"[\s,]+", attrs["data-component-page"].strip())
                if item
            )
        for name in attrs:
            if name.lower().startswith("on"):
                self.page.inline_handlers.append((name, line))

        if tag == "a" and attrs.get("href"):
            self.page.links.append((attrs["href"], line))
            if "component-link" in classes:
                component = ComponentLink(
                    href=attrs["href"],
                    label=attrs.get("aria-label", ""),
                    line=line,
                    in_svg="svg" in self._tags,
                )
                self.page.component_links.append(component)
                self._component_stack.append(component)
        if attrs.get("data-component-ref"):
            ref = (attrs["data-component-ref"], line)
            if self._component_stack:
                self._component_stack[-1].refs.append(ref)
            else:
                self.page.detached_refs.append(ref)

        if tag in {"script", "img", "source", "iframe"} and attrs.get("src"):
            self.page.assets.append((tag, attrs["src"], line))
        if tag == "link" and attrs.get("href"):
            self.page.assets.append((tag, attrs["href"], line))
        self._tags.append(tag)

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self._in_title = False
        if tag == "a" and self._component_stack:
            self._component_stack.pop()
        if tag in self._tags:
            reverse_index = self._tags[::-1].index(tag)
            del self._tags[len(self._tags) - reverse_index - 1 :]

    def handle_startendtag(
        self, tag: str, attrs_list: list[tuple[str, str | None]]
    ) -> None:
        self.handle_starttag(tag, attrs_list)
        self.handle_endtag(tag)

    def handle_data(self, data: str) -> None:
        if self._in_title and data.strip():
            self.page.title = True


def local_target(page: Path, raw_url: str, root: Path) -> tuple[Path, str] | None:
    split = urlsplit(raw_url)
    if split.scheme or split.netloc or raw_url.startswith(("mailto:", "tel:")):
        return None
    path_text = unquote(split.path)
    target = page if not path_text else (page.parent / path_text)
    if target.is_dir() or path_text.endswith("/"):
        target /= "index.html"
    try:
        resolved = target.resolve()
        resolved.relative_to(root)
    except (OSError, ValueError):
        return Path("/__outside_site__"), split.fragment
    return resolved, unquote(split.fragment)


def parse_pages(root: Path) -> dict[Path, Page]:
    pages: dict[Path, Page] = {}
    for path in sorted(root.rglob("*.html")):
        parser = PageParser(path)
        try:
            parser.feed(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as exc:
            raise ValueError(f"cannot read {path}: {exc}") from exc
        pages[path.resolve()] = parser.page
    return pages


def payload_files(root: Path) -> tuple[list[Path], list[str]]:
    files: list[Path] = []
    errors: list[str] = []
    for path in sorted(root.rglob("*")):
        rel = path.relative_to(root)
        if any(part.startswith(".") for part in rel.parts):
            errors.append(f"hidden path is not publishable: {rel}")
            continue
        if path.is_symlink():
            errors.append(f"symlink is not publishable: {rel}")
            continue
        if path.is_dir():
            continue
        if not path.is_file():
            errors.append(f"non-regular path is not publishable: {rel}")
            continue
        if path.suffix.lower() not in ALLOWED_SUFFIXES:
            errors.append(f"unexpected file type in publish payload: {rel}")
            continue
        files.append(rel)
    return files, errors


def css_errors(path: Path, root: Path) -> list[str]:
    rel = path.relative_to(root)
    text = path.read_text(encoding="utf-8")
    clean = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    errors: list[str] = []
    required = {
        "a color-scheme declaration": r"\bcolor-scheme\s*:",
        "a :focus-visible rule": r":focus-visible\s*[^,{]*\{",
        "a prefers-reduced-motion media query": r"@media\s*\([^)]*prefers-reduced-motion",
    }
    for description, pattern in required.items():
        if not re.search(pattern, clean, flags=re.IGNORECASE):
            errors.append(f"{rel}: missing {description}")
    if re.search(r"@import\s+(?:url\()?\s*['\"]?(?:https?:|//|data:)", clean, re.I):
        errors.append(f"{rel}: remote @import dependency")
    if re.search(r"url\(\s*['\"]?(?:https?:|//|data:|javascript:)", clean, re.I):
        errors.append(f"{rel}: remote or embedded url() dependency")
    return errors


def css_local_dependencies(path: Path, root: Path) -> tuple[set[Path], list[str]]:
    text = re.sub(
        r"/\*.*?\*/", "", path.read_text(encoding="utf-8"), flags=re.DOTALL
    )
    dependencies: set[Path] = set()
    errors: list[str] = []
    for match in re.finditer(r"url\(\s*(['\"]?)(.*?)\1\s*\)", text, re.I):
        raw = match.group(2).strip()
        if not raw or raw.startswith("#"):
            continue
        target = local_target(path, raw, root)
        if target is None:
            continue
        target_path, _ = target
        if str(target_path) == "/__outside_site__":
            errors.append(f"{path.relative_to(root)}: CSS url escapes site root: {raw}")
        elif not target_path.is_file():
            errors.append(f"{path.relative_to(root)}: missing CSS asset: {raw}")
        else:
            dependencies.add(target_path)
    return dependencies, errors


def payload_digest(root: Path, payload: list[Path]) -> str:
    digest = hashlib.sha256()
    for rel in payload:
        encoded = rel.as_posix().encode("utf-8")
        digest.update(len(encoded).to_bytes(8, "big"))
        digest.update(encoded)
        data = (root / rel).read_bytes()
        digest.update(len(data).to_bytes(8, "big"))
        digest.update(data)
    return digest.hexdigest()


def secret_errors(root: Path, payload: list[Path]) -> list[str]:
    errors: list[str] = []
    text_suffixes = {".css", ".htm", ".html", ".js", ".json", ".svg", ".txt"}
    for rel in payload:
        if rel.suffix.lower() not in text_suffixes:
            continue
        path = root / rel
        if path.stat().st_size > 2_000_000:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeError:
            continue
        if SECRET_ASSIGNMENT.search(text) or PRIVATE_KEY_HEADER.search(text):
            errors.append(f"possible secret assignment in publish payload: {rel}")
    return errors


def validate(root: Path) -> tuple[list[str], list[str], int, list[Path]]:
    errors: list[str] = []
    warnings: list[str] = []
    root = root.resolve()
    if not root.is_dir():
        return [f"site directory does not exist: {root}"], warnings, 0, []
    if not (root / "index.html").is_file():
        errors.append("missing root index.html")

    all_payload, payload_problems = payload_files(root)
    errors.extend(payload_problems)

    pages = parse_pages(root)
    if len(pages) < 2:
        errors.append("site must contain multiple HTML files")

    component_count = 0
    ref_targets: dict[str, set[Path]] = {}
    page_edges: dict[Path, set[Path]] = {path: set() for path in pages}
    referenced_files: set[Path] = set(pages)
    for path, page in pages.items():
        rel = path.relative_to(root)
        if not page.title:
            errors.append(f"{rel}: missing non-empty <title>")
        if not page.lang:
            errors.append(f"{rel}: <html> needs a lang attribute")
        if page.main_count != 1:
            errors.append(f"{rel}: expected exactly one <main>, found {page.main_count}")
        duplicate_ids = sorted({item for item in page.ids if page.ids.count(item) > 1})
        for item in duplicate_ids:
            errors.append(f"{rel}: duplicate id #{item}")
        for handler, line in page.inline_handlers:
            errors.append(f"{rel}:{line}: inline event handler {handler} is not allowed")

        for ref, line in page.detached_refs:
            errors.append(
                f"{rel}:{line}: data-component-ref {ref!r} is outside a component link"
            )

        for component in page.component_links:
            href, label, line = component.href, component.label, component.line
            component_count += 1
            if not component.in_svg:
                errors.append(f"{rel}:{line}: component link must be inside an SVG")
            if not label.strip():
                errors.append(f"{rel}:{line}: component link needs aria-label")
            if not component.refs:
                errors.append(
                    f"{rel}:{line}: component link must contain data-component-ref"
                )
            target = local_target(path, href, root)
            if target is None:
                errors.append(f"{rel}:{line}: component link must have a local href: {href}")
            elif target[0].suffix.lower() not in {".html", ".htm"}:
                errors.append(f"{rel}:{line}: component link must target HTML: {href}")
            else:
                for ref, ref_line in component.refs:
                    key = ref.strip().upper()
                    if not key:
                        errors.append(f"{rel}:{ref_line}: empty data-component-ref")
                    else:
                        ref_targets.setdefault(key, set()).add(target[0])
                        target_page = pages.get(target[0])
                        if target_page and key not in target_page.component_page_refs:
                            errors.append(
                                f"{rel}:{line}: component {key} target does not declare "
                                f'data-component-page="{key}": {href}'
                            )

        for href, line in page.links:
            split = urlsplit(href)
            if split.scheme.lower() in DANGEROUS_LINK_SCHEMES:
                errors.append(f"{rel}:{line}: unsafe link scheme: {href}")
                continue
            target = local_target(path, href, root)
            if target is None:
                continue
            target_path, fragment = target
            if str(target_path) == "/__outside_site__":
                errors.append(f"{rel}:{line}: link escapes site root: {href}")
                continue
            if not target_path.is_file():
                errors.append(f"{rel}:{line}: missing local target: {href}")
                continue
            if target_path in pages:
                page_edges[path].add(target_path)
            referenced_files.add(target_path)
            if fragment:
                target_page = pages.get(target_path)
                if target_page is None:
                    errors.append(f"{rel}:{line}: fragment points to non-HTML target: {href}")
                elif fragment not in target_page.ids:
                    errors.append(f"{rel}:{line}: missing fragment #{fragment} in {href}")

        for tag, src, line in page.assets:
            split = urlsplit(src)
            if split.scheme or split.netloc:
                errors.append(f"{rel}:{line}: non-local {tag} dependency: {src}")
                continue
            target = local_target(path, src, root)
            if target and not target[0].is_file():
                errors.append(f"{rel}:{line}: missing local {tag} asset: {src}")
            elif target:
                referenced_files.add(target[0])

    if component_count == 0:
        errors.append("no SVG links with class component-link found")
    for ref, targets in sorted(ref_targets.items()):
        if len(targets) > 1:
            rendered = ", ".join(str(item.relative_to(root)) for item in sorted(targets))
            errors.append(f"component ref {ref} has multiple canonical targets: {rendered}")

    entry = (root / "index.html").resolve()
    reachable: set[Path] = set()
    pending = [entry] if entry in pages else []
    while pending:
        current = pending.pop()
        if current in reachable:
            continue
        reachable.add(current)
        pending.extend(page_edges.get(current, set()) - reachable)
    for unreachable in sorted(set(pages) - reachable):
        errors.append(f"unreachable HTML page: {unreachable.relative_to(root)}")

    css = root / "assets" / "styles.css"
    js = root / "assets" / "site.js"
    if not css.is_file():
        errors.append("missing shared assets/styles.css")
    else:
        errors.extend(css_errors(css, root))
        referenced_files.add(css.resolve())
    for css_path in sorted(path for path in referenced_files if path.suffix.lower() == ".css"):
        dependencies, dependency_errors = css_local_dependencies(css_path, root)
        referenced_files.update(dependencies)
        errors.extend(dependency_errors)
    if not js.is_file():
        errors.append("missing shared assets/site.js")
    else:
        referenced_files.add(js.resolve())

    payload = sorted(path.relative_to(root) for path in referenced_files if path.is_file())
    unreferenced = sorted(set(all_payload) - set(payload))
    for rel in unreferenced:
        errors.append(f"unreferenced file is not publishable: {rel}")
    errors.extend(secret_errors(root, payload))
    if not payload:
        errors.append("publish payload contains no files")
    return errors, warnings, component_count, payload


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("site_dir", type=Path)
    parser.add_argument(
        "--manifest",
        type=Path,
        help="write the validated publish payload as relative paths",
    )
    parser.add_argument(
        "--digest-file",
        type=Path,
        help="write a SHA-256 digest of payload paths and contents",
    )
    args = parser.parse_args()
    try:
        errors, warnings, count, payload = validate(args.site_dir)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    for warning in warnings:
        print(f"WARNING: {warning}")
    for error in errors:
        print(f"ERROR: {error}")
    if errors:
        print(f"FAILED: {len(errors)} error(s), {len(warnings)} warning(s)")
        return 1
    if args.manifest:
        args.manifest.write_text(
            "".join(f"{path.as_posix()}\n" for path in payload), encoding="utf-8"
        )
    digest = payload_digest(args.site_dir.resolve(), payload)
    if args.digest_file:
        args.digest_file.write_text(f"{digest}\n", encoding="ascii")
    print(
        f"PASS: {count} component link(s), {len(payload)} payload file(s), "
        f"sha256 {digest}, {len(warnings)} warning(s)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
