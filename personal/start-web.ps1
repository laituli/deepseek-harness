# Personal fork entrypoint: rebuild and restart the dsh web GUI. Run it again
# after any dsh or plugin change and the new instance is fully current.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File personal/start-web.ps1
#   .\personal\start-web.ps1 -SkipShell
#
# Default run: rebuilds the apps/web shell, materializes the web profile's
# recorded plugin set (dsh plugin --profile web install — a no-op when the
# profile is current), stops whatever dsh web listens on port 3080, then
# starts a fresh instance with the combined output teed to .dsh-web-log.txt.
# -SkipShell skips the (slow) vite shell build. The personal plugins live in
# the web profile (installed with `dsh plugin`), not in this tree. Ctrl+C
# stops the server.

param([switch]$SkipShell)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# Local Node 22 (node22/ is gitignored; downloaded once per machine). Fall back
# to whatever node/npx is already on PATH when it is absent.
$nodeDir = Join-Path $repoRoot 'node22\node-v22.23.2-win-x64'
if (Test-Path -LiteralPath $nodeDir) {
  $env:Path = "$nodeDir;$env:Path"
} else {
  Write-Warning "local Node not found at $nodeDir; using node/npx already on PATH"
}

# Personal runtime state lives inside the tree (never committed).
$env:XDG_STATE_HOME = Join-Path $repoRoot '.xdg-state'
$env:XDG_CACHE_HOME = Join-Path $repoRoot '.xdg-cache'
$env:DSH_HOME = $repoRoot

# Rebuild before stopping, so a failed build leaves the running GUI untouched.
Push-Location -LiteralPath $repoRoot
try {
  if (-not $SkipShell) {
    Write-Host '== build web shell (apps/web dist)'
    & npx --yes pnpm@11.7.0 run build:web
    if ($LASTEXITCODE -ne 0) { throw "web shell build failed (exit $LASTEXITCODE)" }
  }

  # Materialize the web profile's recorded plugin set (a no-op when current;
  # needed after a pull changed profiles/web/package.json or the lockfile).
  # Fails before the old server is stopped, so a broken install never takes
  # the running GUI down.
  Write-Host '== ensure web profile plugins (dsh plugin install)'
  & npx --yes pnpm@11.7.0 dsh plugin --profile web install
  if ($LASTEXITCODE -ne 0) { throw "profile plugin install failed (exit $LASTEXITCODE)" }

  # Stop the old instance (dsh web listens on 3080). Socket enumeration is
  # restricted in some sessions, so fall back to netstat when nothing shows.
  $webPids = @()
  $listeners = Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue
  foreach ($listener in $listeners) {
    $proc = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
    if ($proc -and $proc.ProcessName -eq 'node') { $webPids += $listener.OwningProcess }
  }
  if ($webPids.Count -eq 0) {
    foreach ($line in (netstat -ano 2>$null)) {
      if ($line -match ':3080\s+\S+\s+LISTENING\s+(\d+)\s*$') {
        $listenerPid = [int]$Matches[1]
        $proc = Get-Process -Id $listenerPid -ErrorAction SilentlyContinue
        if ($proc -and $proc.ProcessName -eq 'node' -and $webPids -notcontains $listenerPid) { $webPids += $listenerPid }
      }
    }
  }
  foreach ($webPid in $webPids) {
    Write-Host "== stop dsh web (PID $webPid); the current GUI session disconnects until the new server is up"
    Stop-Process -Id $webPid -Force
  }
  for ($i = 0; $i -lt 20; $i++) {
    if (Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue) {
      Start-Sleep -Milliseconds 500
    } else {
      break
    }
  }

  Write-Host '== start dsh web'
  npx --yes pnpm@11.7.0 dsh web 2>&1 | Tee-Object -FilePath (Join-Path $repoRoot '.dsh-web-log.txt')
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
