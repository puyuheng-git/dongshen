#Requires -Version 5.1
<# 
.SYNOPSIS
  Sum git added lines (by author + time range) for multiple OA repo subdirectories.

.DESCRIPTION
  For each repo directory under OARoot, checks out `master`, pulls latest, then runs:
    git log --since --before --author --pretty=tformat: --numstat
  and sums the "added" column from numstat rows.

.PARAMETER OARoot
  OA root directory (default D:\MYOA\webroot)

.PARAMETER Since
  git --since value, e.g. "2026-02-26 12:00:00"

.PARAMETER Before
  git --before value, e.g. "2026-03-26 12:00:00"

.PARAMETER Author
  git --author value, e.g. "puyueheng"

.PARAMETER Dirs
  Repo subdirectories under OARoot (default general/inc/module/task/helper)
#>
[CmdletBinding()]
param(
  [string]$OARoot = 'D:\MYOA\webroot',
  [Parameter(Mandatory = $true)][string]$Since,
  [Parameter(Mandatory = $true)][string]$Before,
  [Parameter(Mandatory = $true)][string]$Author,
  [string[]]$Dirs = @('general', 'inc', 'module', 'task', 'helper'),
  [string]$Branch = 'master'
)

$ErrorActionPreference = 'Stop'

function Get-GitAddedLines([string]$RepoDir, [string]$Since, [string]$Before, [string]$Author) {
  $p = $RepoDir

  # Ensure clean on master and pull latest
  & git -C $p checkout $Branch *> $null
  & git -C $p pull | Out-Null

  $added = 0
  $logOut = & git -C $p log --since=$Since --before=$Before --author=$Author --pretty=tformat: --numstat

  foreach ($line in $logOut) {
    if ($line -match '^\s*([0-9]+|-)\s+([0-9]+|-)\s+') {
      $a = $matches[1]
      if ($a -eq '-') { continue }
      $added += [int]$a
    }
  }

  return $added
}

$results = @{}
$total = 0

foreach ($d in $Dirs) {
  $repoPath = Join-Path $OARoot $d
  $val = Get-GitAddedLines -RepoDir $repoPath -Since $Since -Before $Before -Author $Author
  $results[$d] = $val
  $total += $val
}

Write-Output '--- added lines (git) per repo ---'
foreach ($d in $Dirs) {
  Write-Output ("{0}`t{1}" -f $d, $results[$d])
}
Write-Output ("addedLinesTotal`t{0}" -f $total)

