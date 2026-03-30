#Requires -Version 5.1
<#
.SYNOPSIS
  Fallback to fetch Confluence "无效代码行数" by HTTP session (no Playwright).

.DESCRIPTION
  1) GET login.action to obtain atlassian-token and login button value.
  2) POST dologin.action with os_username/os_password/os_destination/token/login.
  3) GET the target page and parse table rows by:
     - cell[0] = 姓名 (PersonName)
     - cell[1] = 无效代码行数 (float, may be decimal)
     - cell[2] = 代码仓库 key (general/inc/module/task/helper)

  If CAPTCHA/login page is returned, this script throws.

.PARAMETER WikiBaseUrl
  e.g. http://wiki.dev.xkmking.com

.PARAMETER PageUrl
  Confluence page URL, e.g. http://wiki.dev.xkmking.com/pages/viewpage.action?pageId=69894162

.PARAMETER Username / Password
  Use -Username/-Password or env CONF_USER / CONF_PASS

.PARAMETER PersonName
  Exact match for name cell; default: 普悦恒 (Unicode code points; no file encoding dependency)

.PARAMETER Repos
  Repo keys to aggregate (default general inc module task helper)
#>
[CmdletBinding()]
param(
  [string]$WikiBaseUrl = 'http://wiki.dev.xkmking.com',
  [Parameter(Mandatory = $true)][string]$PageUrl,
  [string]$Username = $env:CONF_USER,
  [string]$Password = $env:CONF_PASS,
  [string]$PersonName = '',
  [string[]]$Repos = @('general', 'inc', 'module', 'task', 'helper')
)

$ErrorActionPreference = 'Stop'

try {
  if ($Host.Name -eq 'ConsoleHost') {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
  }
} catch { }

if ([string]::IsNullOrEmpty($PersonName)) {
  # Pu Yue Heng / 普悦恒 — U+666E U+60A6 U+6052
  $PersonName = [string]::Concat([char]0x666E, [char]0x60A6, [char]0x6052)
}

if (-not $Username) { throw 'Set -Username or env CONF_USER' }
if (-not $Password) { throw 'Set -Password or env CONF_PASS' }

function Get-HtmlDecoded([string]$s) {
  if ([string]::IsNullOrEmpty($s)) { return '' }
  return [System.Net.WebUtility]::HtmlDecode($s).Trim()
}

function Strip-HtmlTags([string]$html) {
  if ([string]::IsNullOrEmpty($html)) { return '' }
  $t = [regex]::Replace($html, '(?is)<script[^>]*>.*?</script>', ' ')
  $t = [regex]::Replace($t, '(?is)<style[^>]*>.*?</style>', ' ')
  $t = [regex]::Replace($t, '(?is)<br\s*/?>', "`n")
  $t = [regex]::Replace($t, '(?is)<[^>]+>', ' ')
  return (Get-HtmlDecoded $t) -replace '\s+', ' '
}

function Get-TrInnerTds([string]$trHtml) {
  $cells = [System.Collections.Generic.List[string]]::new()
  $mm = [regex]::Matches($trHtml, '(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>')
  foreach ($m in $mm) {
    $cells.Add((Strip-HtmlTags $m.Groups[1].Value))
  }
  return , $cells.ToArray()
}

function Test-IsLoginOrCaptchaPage([string]$html) {
  if ($html -match '(?i)captcha') { return $true }
  if ($html -match 'name="os_username"' -and $html -match 'Log in to Confluence') { return $true }
  if ($html -match '<title>[^<]*[\u767B\u5F55][^<]*</title>') { return $true }
  return $false
}

$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$relPath = '/' + ($PageUrl -replace '^https?://[^/]+', '').TrimStart('/')
$loginGetUrl = $WikiBaseUrl + '/login.action?os_destination=' + [uri]::EscapeDataString($relPath)

$loginPage = Invoke-WebRequest -Uri $loginGetUrl -WebSession $session -Method GET -UseBasicParsing
$lc = $loginPage.Content

$tokenMatch = [regex]::Match($lc, 'id="atlassian-token"[^>]+content="([^"]+)"')
if (-not $tokenMatch.Success) { throw 'atlassian-token not found on login page' }
$token = $tokenMatch.Groups[1].Value

$destMatch = [regex]::Match($lc, 'name="os_destination"[^>]*value="([^"]*)"')
$osDestination = if ($destMatch.Success) { $destMatch.Groups[1].Value } else { $relPath }

$loginBtnValMatch = [regex]::Match($lc, 'name="login"[^>]*value="([^"]*)"')
if ($loginBtnValMatch.Success) {
  $loginVal = $loginBtnValMatch.Groups[1].Value
} else {
  # fallback string: 登录, encoded by Unicode code points
  $loginVal = [string][char]0x767B + [string][char]0x5F55
}

$form = @{
  os_username    = $Username
  os_password    = $Password
  os_destination = $osDestination
  token          = $token
  login          = $loginVal
}

$null = Invoke-WebRequest -Uri ($WikiBaseUrl + '/dologin.action') -WebSession $session -Method POST -Body $form -UseBasicParsing

$page = Invoke-WebRequest -Uri $PageUrl -WebSession $session -Method GET -UseBasicParsing
$html = $page.Content

if (Test-IsLoginOrCaptchaPage $html) {
  throw 'Still on login or CAPTCHA page. HTTP fallback cannot pass CAPTCHA.'
}

$repoSet = @{}
foreach ($r in $Repos) { $repoSet[$r.ToLowerInvariant()] = $true }
$sums = @{}
foreach ($r in $Repos) { $sums[$r] = 0.0 }

$trMatches = [regex]::Matches($html, '(?is)<tr\b[^>]*>.*?</tr>')
foreach ($tm in $trMatches) {
  $tr = $tm.Value
  $tds = Get-TrInnerTds $tr
  if ($tds.Count -lt 3) { continue }
  if ($tds[0] -ne $PersonName) { continue }

  $invalidRaw = ($tds[1] -replace ',', '').Trim()
  $repo = $tds[2].Trim().ToLowerInvariant()
  if (-not $repoSet.ContainsKey($repo)) { continue }

  $v = 0.0
  if (-not [double]::TryParse($invalidRaw, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$v)) { continue }
  $sums[$repo] += $v
}

Write-Output ("page: {0}" -f $PageUrl)
Write-Output ("person: {0}" -f $PersonName)
Write-Output '--- invalid lines total ---'
foreach ($r in $Repos) {
  Write-Output ("{0}`t{1}" -f $r, $sums[$r])
}

