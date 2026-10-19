<#
 * @Description: 将 Copilot 记忆（用户记忆 + 指定工作区的仓库记忆）导出为可迁移目录包
 * @Author: ytyang
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$WorkspaceFile = ''
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

$codeUser = Get-CodeUserDir
Write-Host "VS Code user dir : $codeUser"

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path

# ---- user memory ----
$userCount = 0
$userSrc = Join-Path $codeUser 'globalStorage\github.copilot-chat\memory-tool\memories'
if (Test-Path $userSrc) {
    $userDst = Join-Path $OutDir 'user-memory'
    New-Item -ItemType Directory -Force -Path $userDst | Out-Null
    $userFiles = @(Get-ChildItem (Join-Path $userSrc '*.md') -File -ErrorAction SilentlyContinue)
    foreach ($f in $userFiles) { Copy-Item $f.FullName $userDst -Force }
    $userCount = $userFiles.Count
}
Write-Host "user memory      : $userCount file(s)"

# ---- repo memory ----
$repoCount = 0
$wsName = '(none)'
$wsPath = '(none)'
$workspaces = @(Get-RepoWorkspaces $codeUser)
if ($workspaces.Count -eq 0) {
    Write-Host "repo memory      : no workspace with repo memory found; skipped"
}
else {
    $target = $null
    if ($WorkspaceFile) {
        $target = $workspaces | Where-Object { $_.Name -like "*$WorkspaceFile*" } | Select-Object -First 1
    }
    elseif ($workspaces.Count -eq 1) {
        $target = $workspaces[0]
    }
    if (-not $target) {
        Write-Host "Specify -WorkspaceFile. Candidates with repo memory:"
        $workspaces | ForEach-Object { Write-Host ("  - " + $_.Name) }
        exit 1
    }
    $repoSrc = Join-Path $target.HashDir 'GitHub.copilot-chat\memory-tool\memories\repo'
    $repoDst = Join-Path $OutDir ('repo-memory\' + $target.Name)
    New-Item -ItemType Directory -Force -Path $repoDst | Out-Null
    $repoFiles = @(Get-ChildItem (Join-Path $repoSrc '*.md') -File -ErrorAction SilentlyContinue)
    foreach ($f in $repoFiles) { Copy-Item $f.FullName $repoDst -Force }
    $repoCount = $repoFiles.Count
    $wsName = $target.Name
    $wsPath = $target.Path
    Write-Host "repo memory      : $repoCount file(s) from '$wsName'"
}

# ---- package README (single-quoted here-string; placeholders replaced below) ----
$template = @'
# GitHub Copilot 记忆导出包

导出时间：{{STAMP}}
来源机用户目录：{{USER_DIR}}
工作区：{{WS_NAME}}
（{{WS_PATH}}）

## 内容

| 目录 | 数量 | 说明 |
| --- | --- | --- |
| user-memory/ | {{USER_COUNT}} | 用户记忆（全局，跨工作区自动加载） |
| repo-memory/{{WS_NAME}}/ | {{REPO_COUNT}} | 仓库记忆（工作区 {{WS_NAME}}） |

会话记忆（memories/<会话ID>/）与聊天记录不在迁移范围。

## 恢复步骤（目标机）

1. 用 memory-sync 技能的导入流程恢复（推荐）：评估 → 确认 → 备份 → 合并。
2. 直接复制（会覆盖同名文件，目标机独有内容会丢失）：
   - user-memory\*.md → %APPDATA%\Code\User\globalStorage\github.copilot-chat\memory-tool\memories\
   - repo-memory\<工作区名>\*.md → %APPDATA%\Code\User\workspaceStorage\<目标机哈希>\GitHub.copilot-chat\memory-tool\memories\repo\
     （哈希用 workspace.json 反查）
3. 验证：新开 Copilot 会话，问「列出你手上的用户记忆文件」。
'@
$readme = $template.
    Replace('{{STAMP}}', (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')).
    Replace('{{USER_DIR}}', $codeUser).
    Replace('{{WS_NAME}}', $wsName).
    Replace('{{WS_PATH}}', $wsPath).
    Replace('{{USER_COUNT}}', [string]$userCount).
    Replace('{{REPO_COUNT}}', [string]$repoCount)
Set-Content -Path (Join-Path $OutDir 'README.md') -Value $readme -Encoding UTF8

Write-Host "README           : written"
Write-Host "Done. Export dir : $OutDir"
