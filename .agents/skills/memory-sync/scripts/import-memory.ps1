<#
 * @Description: 从导出包导入 Copilot 记忆：自动备份目标机现有记忆，-Skip 指定留给手工合并的文件
 * @Author: ytyang
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [string]$WorkspaceFile = '',
    [string[]]$Skip = @()
)

$ErrorActionPreference = 'Stop'

function Get-CodeUserDir {
    $candidates = @(
        (Join-Path $env:APPDATA 'Code\User'),
        (Join-Path $env:APPDATA 'Code - Insiders\User')
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    throw "VS Code user dir not found under $env:APPDATA"
}

# 列出所有存在仓库记忆的工作区：Name / HashDir / Path
function Get-RepoWorkspaces([string]$CodeUser) {
    $result = @()
    $files = Get-ChildItem (Join-Path $CodeUser 'workspaceStorage\*\GitHub.copilot-chat\memory-tool\memories\repo\*.md') -ErrorAction SilentlyContinue
    $hashDirs = @($files | ForEach-Object {
        $i = $_.FullName.IndexOf('\GitHub.copilot-chat\')
        if ($i -gt 0) { $_.FullName.Substring(0, $i) }
    } | Sort-Object -Unique)
    foreach ($hashDir in $hashDirs) {
        $meta = Join-Path $hashDir 'workspace.json'
        if (-not (Test-Path $meta)) { continue }
        $decoded = [uri]::UnescapeDataString([IO.File]::ReadAllText($meta))
        $m = [regex]::Match($decoded, '"file:///([^"]+)"')
        $path = if ($m.Success) { $m.Groups[1].Value } else { '' }
        $result += [pscustomobject]@{ Name = (Split-Path ($path -replace '/', '\') -Leaf); HashDir = $hashDir; Path = $path }
    }
    return $result
}

function Test-Skipped([string]$Scope, [string]$Name, [string[]]$List) {
    foreach ($s in $List) {
        $parts = $s -split ':', 2
        if ($parts.Count -eq 2 -and $parts[0].Trim().ToLower() -eq $Scope -and $parts[1].Trim() -eq $Name) { return $true }
    }
    return $false
}

$Source = (Resolve-Path $Source).Path
$codeUser = Get-CodeUserDir

$userSrc = Join-Path $Source 'user-memory'
$repoSrcRoot = Join-Path $Source 'repo-memory'
$hasUser = Test-Path $userSrc
$hasRepo = Test-Path $repoSrcRoot
if (-not $hasUser -and -not $hasRepo) {
    Write-Host "No user-memory or repo-memory folder under: $Source"
    exit 1
}

# ---- 目标位置 ----
$userDst = Join-Path $codeUser 'globalStorage\github.copilot-chat\memory-tool\memories'
$repoDst = $null
$repoName = $null

if ($hasRepo) {
    $repoNames = @(Get-ChildItem $repoSrcRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    if ($repoNames.Count -eq 0) { $hasRepo = $false }
    else {
        if ($WorkspaceFile) { $repoName = $repoNames | Where-Object { $_ -like "*$WorkspaceFile*" } | Select-Object -First 1 }
        elseif ($repoNames.Count -eq 1) { $repoName = $repoNames[0] }
        if (-not $repoName) {
            Write-Host "Specify -WorkspaceFile. Candidates in package:"
            $repoNames | ForEach-Object { Write-Host ("  - " + $_) }
            exit 1
        }
        $target = @(Get-RepoWorkspaces $codeUser) | Where-Object { $_.Name -like "*$repoName*" } | Select-Object -First 1
        if (-not $target) {
            Write-Host "Workspace storage for '$repoName' not found on this machine."
            Write-Host "Open that workspace in VS Code once (so workspaceStorage is created), then retry."
            exit 1
        }
        $repoDst = Join-Path $target.HashDir 'GitHub.copilot-chat\memory-tool\memories\repo'
    }
}

# ---- 备份目标机现有记忆 ----
$backupDir = Join-Path $Source 'pre-import-backup'
if (Test-Path $backupDir) { $backupDir = Join-Path $Source ('pre-import-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
New-Item -ItemType Directory -Force -Path (Join-Path $backupDir 'user'), (Join-Path $backupDir 'repo') | Out-Null
if (Test-Path $userDst) {
    foreach ($f in @(Get-ChildItem (Join-Path $userDst '*.md') -File -ErrorAction SilentlyContinue)) {
        Copy-Item $f.FullName (Join-Path $backupDir 'user') -Force
    }
}
if ($repoDst -and (Test-Path $repoDst)) {
    foreach ($f in @(Get-ChildItem (Join-Path $repoDst '*.md') -File -ErrorAction SilentlyContinue)) {
        Copy-Item $f.FullName (Join-Path $backupDir 'repo') -Force
    }
}
Write-Host "Backup           : $backupDir"

# ---- 复制用户记忆 ----
if ($hasUser) {
    New-Item -ItemType Directory -Force -Path $userDst | Out-Null
    $copied = 0; $skipped = 0
    foreach ($f in @(Get-ChildItem (Join-Path $userSrc '*.md') -File -ErrorAction SilentlyContinue)) {
        if (Test-Skipped 'user' $f.Name $Skip) { $skipped++; continue }
        Copy-Item $f.FullName $userDst -Force
        $copied++
    }
    Write-Host "user memory      : copied $copied, skipped $skipped"
}

# ---- 复制仓库记忆 ----
if ($hasRepo -and $repoDst) {
    New-Item -ItemType Directory -Force -Path $repoDst | Out-Null
    $copied = 0; $skipped = 0
    foreach ($f in @(Get-ChildItem (Join-Path (Join-Path $repoSrcRoot $repoName) '*.md') -File -ErrorAction SilentlyContinue)) {
        if (Test-Skipped 'repo' $f.Name $Skip) { $skipped++; continue }
        Copy-Item $f.FullName $repoDst -Force
        $copied++
    }
    Write-Host "repo memory      : copied $copied, skipped $skipped ('$repoName')"
}

Write-Host "Done. Skipped files must be merged manually with the memory tool."
