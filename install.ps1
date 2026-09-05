#Requires -Version 7.0
<#
.SYNOPSIS
  ClaudeDefaultSetup installer for Windows. Idempotent: re-run to pull updates.
.DESCRIPTION
  Mirrors install.sh. Requires Git for Windows (provides bash for the status
  line and hooks), jq, and PowerShell 7+. ProjectMan step needs pipx.
    .\install.ps1                      everything
    .\install.ps1 -SkipProjectMan
    .\install.ps1 -Only statusline,hooks
  NOTE: written alongside the bash installer but not exercised on a Windows box
  yet. Run .\verify.sh from Git Bash afterwards and report anything odd.
#>
[CmdletBinding()]
param(
  [string[]]$Only = @(),
  [switch]$SkipProjectMan
)
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Cfg  = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }

function Log($m)  { Write-Host "[setup] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[setup] $m" -ForegroundColor Yellow }
function Want($m) { $Only.Count -eq 0 -or $Only -contains $m }

function Install-File($src, $dst) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
  if ((Test-Path $dst) -and ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash)) { return }
  if (Test-Path $dst) { Copy-Item $dst "$dst.bak" -Force; Log "backed up $dst -> $dst.bak" }
  Copy-Item $src $dst -Force
  Log "wrote $dst"
}

# --- 0. dependencies ---------------------------------------------------------
$missing = @()
foreach ($t in 'git', 'jq', 'bash') { if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { $missing += $t } }
if ($missing.Count) {
  throw "missing: $($missing -join ', '). Install Git for Windows (git + bash) and 'winget install jqlang.jq', then re-run."
}
New-Item -ItemType Directory -Force -Path $Cfg | Out-Null

# --- 1. status line ----------------------------------------------------------
if (Want 'statusline') { Install-File "$Here\statusline\statusline.sh" "$Cfg\statusline.sh" }

# --- 2. attribution ----------------------------------------------------------
if (Want 'attribution') {
  $hooksDir = Join-Path $HOME '.git-hooks'
  Install-File "$Here\attribution\commit-msg" "$hooksDir\commit-msg"
  $want = ($hooksDir -replace '\\', '/')
  $cur = (git config --global core.hooksPath 2>$null)
  if (-not $cur) { git config --global core.hooksPath $want; Log "set core.hooksPath=$want" }
  elseif (($cur -replace '\\', '/') -ne $want -and $cur -ne '~/.git-hooks') {
    Warn "core.hooksPath is already '$cur' (Husky or similar). Left unchanged."
  }
}

# --- 3. hooks ----------------------------------------------------------------
if (Want 'hooks') {
  Get-ChildItem "$Here\hooks\*.sh" | ForEach-Object { Install-File $_.FullName "$Cfg\hooks\$($_.Name)" }
}

# --- 4. slash commands -------------------------------------------------------
if (Want 'commands') {
  Get-ChildItem "$Here\commands\*.md" | Where-Object Name -ne 'INSTALL.md' |
    ForEach-Object { Install-File $_.FullName "$Cfg\commands\$($_.Name)" }
}

# --- 5. settings merge -------------------------------------------------------
function Merge-Into([hashtable]$cur, [hashtable]$tpl) {
  foreach ($k in $tpl.Keys) {
    $t = $tpl[$k]
    if ($cur.ContainsKey($k) -and $cur[$k] -is [hashtable] -and $t -is [hashtable]) {
      Merge-Into $cur[$k] $t
    } elseif ($cur.ContainsKey($k) -and $cur[$k] -is [array] -and $t -is [array]) {
      # union, deduplicated by JSON form (works for strings and hook objects alike)
      $seen = @{}; $out = @()
      foreach ($x in @($cur[$k]) + @($t)) {
        $key = ($x | ConvertTo-Json -Compress -Depth 20)
        if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; $out += ,$x }
      }
      $cur[$k] = $out
    } else {
      $cur[$k] = $t
    }
  }
}
if (Want 'settings') {
  $target = Join-Path $Cfg 'settings.json'
  $tplText = Get-Content "$Here\settings\settings.template.json" -Raw
  if ($Cfg -ne (Join-Path $HOME '.claude')) { $tplText = $tplText -replace '~/\.claude', ($Cfg -replace '\\', '/') }
  $tpl = $tplText | ConvertFrom-Json -AsHashtable -Depth 20
  $cur = @{}
  if (Test-Path $target) {
    try { $cur = Get-Content $target -Raw | ConvertFrom-Json -AsHashtable -Depth 20 }
    catch { throw "existing settings.json is not valid JSON, refusing to touch: $target" }
    if ($null -eq $cur) { $cur = @{} }
  }
  $before = ($cur | ConvertTo-Json -Depth 20 -Compress)
  Merge-Into $cur $tpl
  $cur.Remove('includeCoAuthoredBy')
  $after = ($cur | ConvertTo-Json -Depth 20 -Compress)
  if ($before -ne $after) {
    if (Test-Path $target) { Copy-Item $target "$target.bak" -Force; Log "backed up $target -> $target.bak" }
    $cur | ConvertTo-Json -Depth 20 | Set-Content -Path $target -Encoding utf8NoBOM
    Log "wrote $target"
  } else { Log "settings.json already up to date" }
}

# --- 6. ProjectMan -----------------------------------------------------------
if ((Want 'projectman') -and -not $SkipProjectMan) {
  if (-not (Get-Command pipx -ErrorAction SilentlyContinue)) {
    Warn "pipx missing. Install with: py -m pip install --user pipx; py -m pipx ensurepath  (then re-run .\install.ps1 -Only projectman)"
  } else {
    # Keep this pin in sync with PROJECTMAN_REF in projectman/install.sh
    $ref = if ($env:PROJECTMAN_REF) { $env:PROJECTMAN_REF } else {
      (Select-String -Path "$Here\projectman\install.sh" -Pattern 'PROJECTMAN_REF="\$\{PROJECTMAN_REF:-([0-9a-f]+)\}"').Matches[0].Groups[1].Value
    }
    $spec = "projectman[all] @ git+https://github.com/Biztactix-Ryan/ProjectMan.git@$ref"
    Log "installing $spec"
    pipx install --force $spec
    Log "running projectman setup-claude --global"
    projectman setup-claude --global
    Install-File "$Here\projectman\skills\projectman-init-wizard\SKILL.md" "$Cfg\skills\projectman-init-wizard\SKILL.md"
  }
}

Log "done. Restart Claude Code. Run ./verify.sh from Git Bash to check the result."
