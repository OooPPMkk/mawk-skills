# Run the ai-school self-review suite (prettier check + type/lint/stylelint).
# @Author ytyang
param(
    [string]$RepoDir = "",
    [string]$Files = ""
)

$ErrorActionPreference = "Continue"

function Write-Step([string]$Name, [string]$Status) {
    Write-Output ("[{0}] {1}" -f $Status, $Name)
}

# Resolve the ai-school repository directory.
if (-not $RepoDir) {
    $cursor = (Get-Location).Path
    while ($cursor) {
        $pkg = Join-Path $cursor "package.json"
        if (Test-Path $pkg) {
            $raw = [IO.File]::ReadAllText($pkg)
            if ($raw -match '"name"\s*:\s*"ai-school"') { $RepoDir = $cursor; break }
        }
        $parent = Split-Path $cursor -Parent
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

if (-not $RepoDir -or -not (Test-Path (Join-Path $RepoDir "package.json"))) {
    Write-Output "ERROR: ai-school repo not found. Pass -RepoDir <path to ai-school>."
    exit 2
}

Write-Output ("Repo: " + $RepoDir)

# Resolve node/npm for the version pinned in .nvmrc (same rule as scripts/nvm-run.cmd),
# so the checks never depend on whichever Node the current shell happens to use.
$version = ""
$nvmrc = Join-Path $RepoDir ".nvmrc"
if (Test-Path $nvmrc) {
    $firstLine = (Get-Content $nvmrc -TotalCount 1)
    if ($firstLine) { $version = $firstLine.Trim().TrimStart("v") }
}

$nodeExe = ""
$npmCmd = ""
if ($version -and $env:NVM_HOME) {
    foreach ($candidate in @((Join-Path $env:NVM_HOME ("v" + $version)), (Join-Path $env:NVM_HOME ("installs\v" + $version)))) {
        if (-not $nodeExe -and (Test-Path (Join-Path $candidate "node.exe"))) {
            $nodeExe = Join-Path $candidate "node.exe"
            $npmCmd = Join-Path $candidate "npm.cmd"
        }
    }
}

if ($npmCmd -and (Test-Path $npmCmd)) {
    Write-Output ("Node: " + $nodeExe)
    $env:PATH = (Split-Path $nodeExe -Parent) + ";" + $env:PATH
} else {
    Write-Output ("WARN: Node " + $version + " not resolved from NVM_HOME, falling back to npm on PATH.")
    $npmCmd = "npm"
}
Write-Output ""

$failed = @()
Push-Location $RepoDir

# 1. prettier --check on the changed files (optional).
if ($Files) {
    $list = @($Files.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    Write-Output "> npx prettier --check <changed files>"
    & $npmCmd exec -- prettier --check @list
    if ($LASTEXITCODE -ne 0) { $failed += "prettier"; Write-Step "prettier" "FAIL" } else { Write-Step "prettier" "PASS" }
    Write-Output ""
} else {
    Write-Output "> prettier skipped (pass -Files ""src/a.ts,src/b.vue"" to check changed files)"
    Write-Output ""
}

# 2. type check, lint and stylelint.
$steps = @("type:check", "lint:check", "stylelint:check")

foreach ($step in $steps) {
    Write-Output ("> npm run " + $step)
    & $npmCmd run $step
    if ($LASTEXITCODE -ne 0) { $failed += $step; Write-Step $step "FAIL" } else { Write-Step $step "PASS" }
    Write-Output ""
}

Pop-Location

if ($failed.Count -gt 0) {
    Write-Output ("FAILED: " + ($failed -join ", "))
    exit 1
}

Write-Output "ALL PASS"
exit 0
