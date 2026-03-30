# Convert files from UTF-8 to GBK encoding
# Usage: powershell -ExecutionPolicy Bypass -File convert_to_gbk.ps1 -files "file1.php,file2.php"
param(
    [string]$files = ""
)
$gbk = [System.Text.Encoding]::GetEncoding('GBK')
$utf8 = New-Object System.Text.UTF8Encoding($false)
if ($files -eq "") {
    Write-Host "Usage: convert_to_gbk.ps1 -files 'file1.php,file2.php'"
    exit 1
}
$fileList = $files -split ","
foreach ($f in $fileList) {
    $f = $f.Trim()
    if (-not (Test-Path $f)) {
        Write-Host "[SKIP] $f - not found"
        continue
    }
    $rawBytes = [System.IO.File]::ReadAllBytes($f)
    # Try UTF-8 decode
    $utf8Text = $utf8.GetString($rawBytes)
    $utf8Chinese = [regex]::Matches($utf8Text, '[\u4e00-\u9fff]')
    # Try GBK decode
    $gbkText = $gbk.GetString($rawBytes)
    $gbkChinese = [regex]::Matches($gbkText, '[\u4e00-\u9fff]')
    if ($utf8Chinese.Count -gt $gbkChinese.Count) {
        # File is UTF-8, convert to GBK
        $gbkBytes = $gbk.GetBytes($utf8Text)
        [System.IO.File]::WriteAllBytes($f, $gbkBytes)
        Write-Host "[CONVERTED] $f (UTF8->GBK, Chinese=$($utf8Chinese.Count))"
    } elseif ($gbkChinese.Count -ge 3) {
        Write-Host "[ALREADY_GBK] $f (Chinese=$($gbkChinese.Count))"
    } else {
        # Check for corruption (literal ? marks)
        $hasQuestionCorruption = $false
        $gbkLines = $gbkText -split "`n"
        foreach ($line in $gbkLines) {
            if ($line -match '^\s*\*\s+\?{3,}') {
                $hasQuestionCorruption = $true
                break
            }
        }
        if ($hasQuestionCorruption) {
            Write-Host "[CORRUPTED] $f - Chinese replaced with '?', needs rewrite from clean UTF-8 source"
        } else {
            Write-Host "[NO_CHINESE] $f"
        }
    }
}
