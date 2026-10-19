# Sync backend service repos to the newest version branch (read-only, no code changes).
# @Author ytyang
param(
    [string]$BackendRoot = "D:\10.project\back-end",
    [string[]]$Repos = @(
        "aiuniv-cloud-core",
        "aiuniv-cloud-ai",
        "aiuniv-cloud-edu",
        "aiuniv-cloud-workspace",
        "aiuniv-cloud-billing",
        "aiuniv-cloud-pay"
    ),
    [switch]$Apply
)

$ErrorActionPreference = "Continue"

if (-not (Test-Path $BackendRoot)) {
    Write-Output ("ERROR: backend root not found: " + $BackendRoot)
    exit 2
}

Write-Output ("Backend root: " + $BackendRoot)
if ($Apply) { Write-Output "Mode: APPLY (working tree will be detached to the newest version)" }
else { Write-Output "Mode: DRY RUN (report only; pass -Apply to update)" }
Write-Output ""

$changed = @()

foreach ($repo in $Repos) {
    $p = Join-Path $BackendRoot $repo
    if (-not (Test-Path $p)) {
        Write-Output ("-- " + $repo + ": MISSING, skipped")
        continue
    }

    $fetch = git -C $p fetch --prune 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Output ("-- " + $repo + ": FETCH FAILED")
        continue
    }

    $head = git -C $p rev-parse --abbrev-ref HEAD 2>$null
    $dirty = (git -C $p status --porcelain 2>$null | Measure-Object).Count

    # Newest version branch: highest origin/1.0.x, fallback to origin/master.
    $best = ""
    $bestVer = $null
    $refs = git -C $p for-each-ref --format="%(refname:short)" "refs/remotes/origin/1.0.*" 2>$null
    foreach ($ref in $refs) {
        $name = $ref -replace "^origin/", ""
        $ver = $null
        try { $ver = [version]$name } catch { continue }
        if (-not $bestVer -or $ver -gt $bestVer) { $bestVer = $ver; $best = $name }
    }
    if (-not $best) {
        if (git -C $p rev-parse --verify --quiet "origin/master" > $null) { $best = "master" }
    }
    if (-not $best) {
        Write-Output ("-- " + $repo + ": no origin/1.0.x or origin/master, skipped")
        continue
    }

    $target = git -C $p rev-parse --short ("origin/" + $best) 2>$null
    $current = git -C $p rev-parse --short HEAD 2>$null
    $state = "up-to-date"
    if ($current -ne $target) { $state = "OUTDATED" }

    Write-Output ("-- " + $repo)
    Write-Output ("   HEAD: " + $head + " (" + $current + ") | newest: " + $best + " (" + $target + ") | " + $state + " | dirty=" + $dirty)

    if ($state -eq "up-to-date") { continue }

    if (-not $Apply) {
        $changed += $repo
        continue
    }
    if ($dirty -gt 0) {
        Write-Output "   SKIP: working tree has local changes, not switching (no stash, no overwrite)"
        continue
    }

    git -C $p switch --detach ("origin/" + $best) 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $newHead = git -C $p rev-parse --short HEAD 2>$null
        Write-Output ("   UPDATED: HEAD is now " + $newHead + " (detached at origin/" + $best + ")")
        $changed += $repo
    } else {
        Write-Output "   FAILED to switch"
    }
}

Write-Output ""
Write-Output "---- existing derived worktrees (refresh by remove + re-add after fetch) ----"
$rootFwd = $BackendRoot -replace "\\", "/"
foreach ($repo in $Repos) {
    $p = Join-Path $BackendRoot $repo
    if (-not (Test-Path $p)) { continue }
    $list = git -C $p worktree list 2>$null
    if ($list -and $list.Count -gt 1) {
        foreach ($line in $list) { if ($line -notmatch ("^" + [regex]::Escape($rootFwd) + "/" + [regex]::Escape($repo) + " ")) { Write-Output $line } }
    }
}

Write-Output ""
if ($Apply) {
    if ($changed.Count -gt 0) { Write-Output ("UPDATED REPOS: " + ($changed -join ", ")) } else { Write-Output "ALL UP TO DATE" }
} else {
    if ($changed.Count -gt 0) { Write-Output ("OUTDATED REPOS: " + ($changed -join ", ") + " -- re-run with -Apply to update") } else { Write-Output "ALL UP TO DATE" }
}
exit 0
