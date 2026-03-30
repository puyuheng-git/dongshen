# Verify GBK encoding for PHP/SQL files
# Usage: powershell -ExecutionPolicy Bypass -File verify_gbk.ps1 -files "file1.php,file2.php"
# Or:    powershell -ExecutionPolicy Bypass -File verify_gbk.ps1 -dir "d:\MYOA\webroot\some\path"
param(
    [string]$files = "",
    [string]$dir = ""
)
$gbk = [System.Text.Encoding]::GetEncoding('GBK')
$utf8 = New-Object System.Text.UTF8Encoding($false)
$fileList = @()
if ($files -ne "") {
    $fileList = $files -split ","
} elseif ($dir -ne "") {
    $fileList = Get-ChildItem -Path $dir -Recurse -Include *.php,*.sql | ForEach-Object { $_.FullName }
}
if ($fileList.Count -eq 0) {
    Write-Host "No files to check."
    exit 0
}
$hasError = $false
foreach ($f in $fileList) {
    $f = $f.Trim()
    if (-not (Test-Path $f)) {
        Write-Host "[SKIP] $f - not found"
        continue
    }
    $rawBytes = [System.IO.File]::ReadAllBytes($f)
    $gbkText = $gbk.GetString($rawBytes)
    $chineseMatches = [regex]::Matches($gbkText, '[\u4e00-\u9fff]')
    $utf8Text = $utf8.GetString($rawBytes)
    $utf8Chinese = [regex]::Matches($utf8Text, '[\u4e00-\u9fff]')
    $fname = [System.IO.Path]::GetFileName($f)
    # Detect literal ? corruption: read as GBK, check comment line for ?
    $lines = $gbkText -split "`n"
    $commentCorrupted = $false
    foreach ($line in $lines) {
        if ($line -match '^\s*\*\s+\?{3,}') {
            $commentCorrupted = $true
            break
        }
    }
    if ($commentCorrupted -or ($chineseMatches.Count -lt 3 -and $utf8Chinese.Count -gt 3)) {
        Write-Host "[FAIL] $f (GBK_Chinese=$($chineseMatches.Count), UTF8_Chinese=$($utf8Chinese.Count)) - NEEDS CONVERSION"
        $hasError = $true
    } elseif ($utf8Chinese.Count -gt $chineseMatches.Count) {
        Write-Host "[UTF8] $f (UTF8_Chinese=$($utf8Chinese.Count)) - NEEDS GBK CONVERSION"
        $hasError = $true
    } elseif ($chineseMatches.Count -ge 3) {
        $sample = ''
        foreach ($line in $lines) {
            if ($line -match '[\u4e00-\u9fff]') {
                $sample = $line.Trim()
                if ($sample.Length -gt 60) { $sample = $sample.Substring(0, 60) }
                break
            }
        }
        Write-Host "[OK] $f (Chinese=$($chineseMatches.Count)) $sample"
    } else {
        Write-Host "[WARN] $f (Chinese=$($chineseMatches.Count)) - very few Chinese chars"
    }
}
if ($hasError) { exit 1 } else { exit 0 }
