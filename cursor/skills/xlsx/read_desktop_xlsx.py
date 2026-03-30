# -*- coding: utf-8 -*-
"""使用 xlsx skill 的 pandas 读取桌面 xlsx，结果输出到 UTF-8 文件避免控制台乱码"""
import os
import sys

path = os.path.join(os.path.expanduser("~"), "Desktop", "33333333.xlsx")
if not os.path.isfile(path):
    print("FILE_NOT_FOUND:", path, file=sys.stderr)
    sys.exit(1)

import pandas as pd
all_sheets = pd.read_excel(path, sheet_name=None)
out_path = os.path.join(os.path.expanduser("~"), "Desktop", "33333333_content.txt")
with open(out_path, "w", encoding="utf-8") as f:
    for name, df in all_sheets.items():
        f.write("=== Sheet: %s  rows: %d  cols: %d ===\n\n" % (name, len(df), len(df.columns)))
        f.write(df.to_string() + "\n\n")
print("OK written:", out_path)
