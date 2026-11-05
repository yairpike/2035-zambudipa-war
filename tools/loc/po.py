"""Minimal gettext PO reader and writer for the game catalogs."""
import re

HEADER = (
    'msgid ""\n'
    'msgstr ""\n'
    '"Project-Id-Version: ASEAN 2031\\n"\n'
    '"Language: {lang}\\n"\n'
    '"MIME-Version: 1.0\\n"\n'
    '"Content-Type: text/plain; charset=UTF-8\\n"\n'
    '"Content-Transfer-Encoding: 8bit\\n"\n'
)


def _esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\t", "\\t").replace("\n", "\\n")


def _unesc(s: str) -> str:
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(n, n))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def _field(name: str, value: str) -> str:
    if "\n" not in value or value.endswith("\n") and value.count("\n") == 1:
        return '%s "%s"\n' % (name, _esc(value))
    parts = value.split("\n")
    lines = ['%s ""\n' % name]
    for i, p in enumerate(parts):
        tail = "\n" if i < len(parts) - 1 else ""
        if p == "" and tail == "":
            continue
        lines.append('"%s"\n' % _esc(p + tail))
    return "".join(lines)


def write(path: str, lang: str, entries: list) -> None:
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(HEADER.format(lang=lang))
        for e in entries:
            f.write("\n")
            for c in e.get("comments", []):
                f.write("#. %s\n" % c)
            if e.get("refs"):
                f.write("#: %s\n" % " ".join(r.replace(" ", "_") for r in e["refs"]))
            f.write(_field("msgid", e["msgid"]))
            f.write(_field("msgstr", e.get("msgstr", "")))


def read(path: str) -> dict:
    out: dict = {}
    cur: dict = {}
    key = None
    comments: list = []

    def flush():
        nonlocal cur, comments
        if "msgid" in cur and cur["msgid"] != "":
            out[cur["msgid"]] = {"msgstr": cur.get("msgstr", ""), "comments": comments}
        cur = {}
        comments = []

    for raw in open(path, encoding="utf-8"):
        line = raw.rstrip("\n")
        if line.startswith("#."):
            comments.append(line[2:].strip())
            continue
        if line.startswith("#") or not line.strip():
            if not line.strip() and "msgstr" in cur:
                flush()
            continue
        m = re.match(r'^(msgid|msgstr)\s+"(.*)"$', line)
        if m:
            if m.group(1) == "msgid" and "msgstr" in cur:
                flush()
            key = m.group(1)
            cur[key] = _unesc(m.group(2))
            continue
        m = re.match(r'^"(.*)"$', line)
        if m and key:
            cur[key] += _unesc(m.group(1))
    if "msgstr" in cur:
        flush()
    return out
