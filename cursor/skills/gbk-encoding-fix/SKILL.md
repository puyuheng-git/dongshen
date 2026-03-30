---
name: gbk-encoding-fix
description: Fix Chinese character encoding issues (mojibake/??? display) in GBK-encoded PHP/SQL files under D:\MYOA\webroot. Use when Chinese characters display as ??? or garbled text after creating or editing files, when file encoding needs to be converted from UTF-8 to GBK, or when verifying that files are correctly GBK-encoded. Triggers on: "中文乱码", "???", "问号", "编码问题", "GBK", "encoding", "mojibake", "garbled Chinese".
---

# GBK Encoding Fix

Fix Chinese character corruption in `D:\MYOA\webroot` PHP/SQL files that must use GBK encoding.

## Root Cause

The Write tool outputs **UTF-8** bytes. The Cursor IDE may auto-convert to GBK, but this is **unreliable** — race conditions between IDE auto-save and subsequent operations cause:
- **Literal `?` corruption** (0x3F bytes replacing Chinese) — **irreversible**, must rewrite from clean source
- **Double encoding** — GBK bytes misread as UTF-8 then re-encoded

## Three File States

| State | Symptom | Read as GBK | Read as UTF-8 | Fix |
|-------|---------|-------------|---------------|-----|
| Correct GBK | Displays correctly in browser/PHP | Chinese chars OK | Garbled | None needed |
| Still UTF-8 | Garbled in browser, OK in UTF-8 editor | Few Chinese | Chinese OK | Convert UTF-8 → GBK |
| Corrupted | Shows literal `???` everywhere | `???` | `???` | **Rewrite** from clean UTF-8, then convert |

## Workflow

### Step 1: Verify Current State

Run the bundled verification script on target files:

```powershell
powershell -ExecutionPolicy Bypass -File "d:\MYOA\webroot\.cursor\skills\gbk-encoding-fix\scripts\verify_gbk.ps1" -files "file1.php,file2.php"
```

Or verify an entire directory:

```powershell
powershell -ExecutionPolicy Bypass -File "d:\MYOA\webroot\.cursor\skills\gbk-encoding-fix\scripts\verify_gbk.ps1" -dir "d:\MYOA\webroot\some\path"
```

Output meanings:
- `[OK]` — File is correctly GBK-encoded, no action needed
- `[UTF8]` — File has UTF-8 Chinese, needs GBK conversion → go to Step 2
- `[FAIL]` — File is corrupted with literal `?` — go to Step 3
- `[WARN]` — Very few Chinese chars, inspect manually

### Step 2: Convert UTF-8 Files to GBK

For files that are valid UTF-8 but need GBK:

```powershell
powershell -ExecutionPolicy Bypass -File "d:\MYOA\webroot\.cursor\skills\gbk-encoding-fix\scripts\convert_to_gbk.ps1" -files "file1.php,file2.php"
```

**Important**: After conversion, re-run Step 1 to verify.

### Step 3: Fix Corrupted Files (literal `?` chars)

When Chinese is replaced with literal `?` (0x3F bytes), the data is **lost** and cannot be recovered by re-encoding. Must rewrite from scratch:

1. **Write to a temp file** using the Write tool with correct UTF-8 Chinese content:
   ```
   Write tool → d:\MYOA\webroot\_tmp_fixfile.php  (with correct Chinese)
   ```

2. **Wait for IDE auto-conversion** — the IDE will detect `<meta charset="GBK">` or project settings and auto-convert the temp file to GBK

3. **Verify temp file** is correct GBK:
   ```powershell
   powershell -ExecutionPolicy Bypass -File "d:\MYOA\webroot\.cursor\skills\gbk-encoding-fix\scripts\verify_gbk.ps1" -files "d:\MYOA\webroot\_tmp_fixfile.php"
   ```

4. **Copy temp file** (byte-level) to target location:
   ```powershell
   Copy-Item -Path 'd:\MYOA\webroot\_tmp_fixfile.php' -Destination 'd:\MYOA\webroot\target\path\file.php' -Force
   ```

5. **Clean up** temp file:
   ```
   Delete tool → d:\MYOA\webroot\_tmp_fixfile.php
   ```

6. **Re-verify** target file with Step 1.

### Step 4: Final Verification

After all fixes, run batch verification on all affected files to confirm everything is OK:

```powershell
powershell -ExecutionPolicy Bypass -File "d:\MYOA\webroot\.cursor\skills\gbk-encoding-fix\scripts\verify_gbk.ps1" -files "file1.php,file2.php,file3.php"
```

All files should show `[OK]`.

## Prevention: Best Practices for Writing GBK Files

### Method A: Write + IDE Auto-Convert (preferred for most files)

1. Use the Write tool to create file with correct UTF-8 Chinese
2. IDE auto-converts to GBK (triggered by `<meta charset="GBK">` in HTML or project settings)
3. Verify with `verify_gbk.ps1`
4. If verification fails, use Method B

### Method B: Write + Explicit Convert (when Method A fails)

1. Write file with Write tool (UTF-8)
2. Immediately run `convert_to_gbk.ps1` on the file
3. Verify with `verify_gbk.ps1`

### Method C: Temp File + Copy (for repeatedly corrupted files)

1. Write to `_tmp_*.php` temp file
2. Verify temp file is GBK
3. `Copy-Item` to final destination
4. Delete temp file

### Critical Rules

- **Never run GBK conversion on a file that is already GBK** — causes double encoding
- **Never assume the IDE will auto-convert** — always verify
- **For files with GBK hex escape sequences** (e.g. `"\xd6\xca\xbf\xd8"` for runtime Chinese strings), encoding of the escape sequences themselves doesn't matter since they are ASCII — only the surrounding comments/labels need GBK encoding
- **Clean up all temp files** (`_tmp_*.php`, `_*.ps1`) after fixing
