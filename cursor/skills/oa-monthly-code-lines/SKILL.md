---
name: oa-monthly-code-lines
description: When the user asks to统计某个月 OA 端 + Service 端代码量（按作者、时间范围、仓库目录分组），并结合 Confluence 表格中的「无效代码行数/报备代码行数」计算每个仓库最终「有效代码行数」。Use when the user provides: (1) time range, (2) author, (3) person name in Confluence, (4) Confluence pageId/url, and (5) repo mappings.
---

## Workflow (optimized by latest run)
0. Month window rule (default and mandatory)
   - Monthly statistics MUST use:
     - `since = (previous month)-26 12:00:00`
     - `before = (current month)-26 12:00:00`
   - Example:
     - "统计 2026 年 2 月" => `2026-01-26 12:00:00 ~ 2026-02-26 12:00:00`
   - If user does not explicitly provide a custom range, always apply this rule.

1. OA side git added lines
   1. For each OA repo under `OARoot` (default: `general`, `inc`, `module`, `task`, `helper`):
      - `git checkout master`
      - `git pull`
      - `git log --since --before --author --pretty=tformat: --numstat`
      - Sum first column of numstat rows as `addedLines`:
        - added `-` means binary file, count as `0`.
   2. Record per-repo OA `addedLines`.

2. Confluence invalid/report lines
   1. Prefer browser flow (Playwright) if available; fallback to script:
      - `scripts/confluence_fetch_person_invalid_lines_fallback.ps1`
   2. Read rows where `姓名 == personName` (default `普悦恒`), aggregate by repo key.
   3. Pull two groups when needed:
      - OA keys: `general/inc/module/task/helper`
      - Service keys: `com-lib/service-app/service-api/open-oa/tool`
   4. Parse invalid lines as float (decimal allowed).

3. OA effective lines
   - `effectiveLines = addedLines - invalidLines`
   - Keep negative values unless user asks for `max(0, x)`.

4. Service side code lines (stat_code_win.php)
   1. Service repos and working dirs:
      - `com-lib`: `D:\39.102.37.69\puyueheng\framework\com-lib`
      - `service-app`: `D:\39.102.37.69\puyueheng\service\service-app`
      - `service-api`: `D:\39.102.37.69\puyueheng\service\service-api`
      - `open-oa`: `D:\39.102.37.69\puyueheng\site\open-oa`
      - `tool`: `D:\39.102.37.69\puyueheng\site\tool`
   2. Command order per repo:
      - `git checkout master`
      - `git pull` (or `git pull origin master` for repos without upstream tracking, such as `tool`)
      - `php "D:\39.102.37.69\puyueheng\stat_code_win.php" "<author>" "<since>" "<before>"`
   3. Parse script output `代码行数: X` as service `codeLines`.
   4. Service effective lines:
      - `effectiveLines = codeLines - invalidLines(报备代码)`

5. Blocking/exception handling (must report clearly)
   - If repo has merge conflict during `git pull` (e.g. `service-api`), STOP and ask user to choose:
     - A) resolve conflict first then continue with strict flow
     - B) run stat on current local state (non-strict fallback)
   - If repo has no upstream on `master`, use `git pull origin master` (without changing git config).
   - In Windows PowerShell, do not use `&&`; use `; if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}` style.

6. Final output format
   - OA table: `repo`, `addedLines`, `invalidLines`, `effectiveLines`
   - Service table: `repo`, `codeLines`, `invalidLines`, `effectiveLines`
   - Totals:
     - OA total: `addedLinesTotal`, `invalidLinesTotal`, `effectiveLinesTotal`
     - Service total: `codeLinesTotal`, `invalidLinesTotal`, `effectiveLinesTotal`
     - Grand total (OA + Service): `codeLinesTotal`, `invalidLinesTotal`, `effectiveLinesTotal`

## Expected inputs
- `OARoot` (default `D:\MYOA\webroot`)
- `author` (default `puyueheng`)
- `month` (recommended, e.g. `2026-02`)
- `since` / `before` (optional; if omitted, derive from 26th-12:00 month window rule)
- `ConfluencePageUrl`
- `personName` (default `普悦恒`)
- Service stat script path: `D:\39.102.37.69\puyueheng\stat_code_win.php`

## Useful defaults
- Team month window (default):
  - `2月`: `2026-01-26 12:00:00 ~ 2026-02-26 12:00:00`
  - `3月`: `2026-02-26 12:00:00 ~ 2026-03-26 12:00:00`

## Scripts included
- `scripts/oa_git_added_lines.ps1`
- `scripts/confluence_fetch_person_invalid_lines_fallback.ps1`

## Notes
- Confluence「无效代码行数/报备代码行数」可能为小数，按 float 处理。
- Never store secrets in files under version control.
- User-level env gotcha:
  - If user sets env by `[Environment]::SetEnvironmentVariable(..., 'User')`, current terminal may not refresh immediately.
  - Prefer explicit read + pass:
    - `$u=[Environment]::GetEnvironmentVariable('CONF_USER','User')`
    - `$p=[Environment]::GetEnvironmentVariable('CONF_PASS','User')`
    - `.\confluence_fetch_person_invalid_lines_fallback.ps1 -PageUrl ... -Username $u -Password $p`
- Quick credential check:
  - `cmd /c "if defined CONF_USER (echo CONF_USER set) else (echo CONF_USER empty) & if defined CONF_PASS (echo CONF_PASS set) else (echo CONF_PASS empty)"`
