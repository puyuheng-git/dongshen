#!/usr/bin/env python3
"""Extract plain text from .docx when pandoc is not available (e.g. Windows)."""
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

NS = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}

def _text_in_elt(elt):
    out = []
    for e in elt.iter():
        if e.tag == "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}t":
            if e.text:
                out.append(e.text)
        elif e.tag == "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}delText":
            if e.text:
                out.append(e.text)
    return "".join(out)

def extract_text(docx_path):
    path = Path(docx_path)
    if not path.is_file() or path.suffix.lower() != ".docx":
        raise SystemExit("Usage: python extract_text.py <file.docx> [output.txt]")
    with zipfile.ZipFile(path, "r") as z:
        with z.open("word/document.xml") as f:
            root = ET.parse(f).getroot()
    body = root.find(".//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}body")
    if body is None:
        return ""
    lines = []
    for p in body.iter("{http://schemas.openxmlformats.org/wordprocessingml/2006/main}p"):
        line = _text_in_elt(p).strip()
        if line:
            lines.append(line)
    return "\n".join(lines)

def main():
    if len(sys.argv) < 2:
        print("Usage: python extract_text.py <file.docx> [output.txt]", file=sys.stderr)
        sys.exit(1)
    docx_path = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else None
    text = extract_text(docx_path)
    if out_path:
        Path(out_path).write_text(text, encoding="utf-8")
        print("Written:", out_path)
    else:
        print(text)

if __name__ == "__main__":
    main()
