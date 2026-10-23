[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]*$')]
    [string]$Owner,
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$RepositoryName = 'journal-citation-audit',
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskRoot = $PSScriptRoot
$taskPublicFiles = @(
    'README.md', 'LICENSE', '.gitignore', 'publish.cmd', 'publish.ps1',
    'skills/journal-citation-audit/SKILL.md',
    'skills/journal-citation-audit/agents/openai.yaml'
)

function Invoke-TaskNative {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $Executable (exit $LASTEXITCODE)" }
}

function Assert-PublicFiles {
    foreach ($taskFile in $taskPublicFiles) {
        $taskPath = Join-Path $taskRoot $taskFile
        if (-not (Test-Path -LiteralPath $taskPath -PathType Leaf)) {
            throw "Missing public file: $taskFile"
        }
        $taskText = [IO.File]::ReadAllText($taskPath)
        if ($taskText -match '(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)') {
            throw "Possible credential in $taskFile. Publishing stopped."
        }
        if ($taskFile -match '\.(?:md|yaml)$') {
            if ($taskText -match '(?i)(?:\b[A-Z]:[\\/]|/Users/|/home/)') {
                throw "Possible private local path in $taskFile. Publishing stopped."
            }
        }
    }
    Write-Host "Public file check passed ($($taskPublicFiles.Count) files)."
}

function Get-TaskGh {
    $taskInstalled = Get-Command gh -ErrorAction SilentlyContinue
    if ($taskInstalled) { return $taskInstalled.Source }
    $taskArch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
    $taskHeaders = @{ 'User-Agent' = 'journal-citation-audit-publisher'; 'Accept' = 'application/vnd.github+json' }
    $taskRelease = Invoke-RestMethod -Uri 'https://api.github.com/repos/cli/cli/releases/latest' -Headers $taskHeaders -TimeoutSec 30
    $taskAsset = @($taskRelease.assets | Where-Object { $_.name -match "^gh_[0-9.]+_windows_$taskArch\.zip`$" })
    if ($taskAsset.Count -ne 1) { throw 'Official GitHub CLI release asset not found.' }
    $taskCache = Join-Path ([IO.Path]::GetTempPath()) ('journal-citation-audit-gh-' + $taskRelease.tag_name + '-' + $taskArch)
    $taskExe = Join-Path $taskCache 'bin/gh.exe'
    if (-not (Test-Path -LiteralPath $taskExe -PathType Leaf)) {
        New-Item -ItemType Directory -Path $taskCache -Force | Out-Null
        $taskArchive = Join-Path $taskCache 'gh.zip'
        Write-Host 'Downloading the official portable GitHub CLI into the temporary directory...'
        Invoke-WebRequest -Uri $taskAsset[0].browser_download_url -OutFile $taskArchive -UseBasicParsing -TimeoutSec 120
        Expand-Archive -LiteralPath $taskArchive -DestinationPath $taskCache -Force
    }
    if (-not (Test-Path -LiteralPath $taskExe -PathType Leaf)) { throw 'GitHub CLI extraction failed.' }
    return $taskExe
}

Assert-PublicFiles
if ($CheckOnly) {
    Write-Host 'No login, repository creation, commit, or push was performed.'
    $taskPublicFiles | ForEach-Object { Write-Host "  $_" }
    return
}

$taskGitCommand = Get-Command git -ErrorAction SilentlyContinue
if (-not $taskGitCommand) { throw 'Git is required. Install Git, then run this script again.' }
$taskGit = $taskGitCommand.Source
$taskGh = Get-TaskGh
& $taskGh auth status --hostname github.com *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Complete GitHub browser authorization yourself. Do not share passwords or tokens.'
    Invoke-TaskNative $taskGh @('auth', 'login', '--hostname', 'github.com', '--git-protocol', 'https', '--web')
}
$taskLogin = (& $taskGh api user --jq .login).Trim()
if ($LASTEXITCODE -ne 0 -or -not $taskLogin) { throw 'Could not identify the authenticated GitHub account.' }
if (-not $Owner) { $Owner = $taskLogin }
$taskFullName = "$Owner/$RepositoryName"
$taskRemote = "https://github.com/$taskFullName.git"

Push-Location -LiteralPath $taskRoot
try {
    $taskHasRepo = Test-Path -LiteralPath (Join-Path $taskRoot '.git')
    $taskHasOrigin = $false
    if ($taskHasRepo) {
        $taskOrigin = & $taskGit remote get-url origin 2>$null
        $taskHasOrigin = $LASTEXITCODE -eq 0
        if ($taskHasOrigin -and $taskOrigin.TrimEnd('/') -ne $taskRemote) {
            throw 'This local repository is attached to a different remote. No change was pushed.'
        }
        $taskTracked = @(& $taskGit ls-files)
        foreach ($taskTrackedFile in $taskTracked) {
            if ($taskTrackedFile -notin $taskPublicFiles) { throw "Unexpected tracked file: $taskTrackedFile" }
        }
        $taskHistoryEmails = @(& $taskGit log --format=%ae%n%ce 2>$null)
        if ($LASTEXITCODE -eq 0 -and @($taskHistoryEmails | Where-Object { $_ -ne 'contributors@example.invalid' }).Count -gt 0) {
            throw 'Existing history contains a non-generic identity. Review it before publishing.'
        }
    }
    if (-not $taskHasOrigin) {
        & $taskGh repo view $taskFullName --json name *> $null
        if ($LASTEXITCODE -eq 0) { throw 'The remote repository already exists. Choose a new repository name.' }
    }

    $taskReadme = Join-Path $taskRoot 'README.md'
    $taskReadmeText = [IO.File]::ReadAllText($taskReadme).Replace('https://github.com/OWNER/REPOSITORY', "https://github.com/$taskFullName")
    [IO.File]::WriteAllText($taskReadme, $taskReadmeText, (New-Object Text.UTF8Encoding($false)))
    Assert-PublicFiles
    if (-not $taskHasRepo) { Invoke-TaskNative $taskGit @('init', '-b', 'main') }
    Invoke-TaskNative $taskGit @('config', '--local', 'user.name', 'Journal Citation Audit contributors')
    Invoke-TaskNative $taskGit @('config', '--local', 'user.email', 'contributors@example.invalid')
    Invoke-TaskNative $taskGit @('config', '--local', 'commit.gpgsign', 'false')
    Invoke-TaskNative $taskGit (@('add', '--') + $taskPublicFiles)
    $taskStaged = @(& $taskGit diff --cached --name-only)
    foreach ($taskStagedFile in $taskStaged) {
        if ($taskStagedFile -notin $taskPublicFiles) { throw "Unexpected staged file: $taskStagedFile" }
    }
    if ($taskStaged.Count -gt 0) {
        $taskIdentityBackup = @{}
        foreach ($taskKey in @('GIT_AUTHOR_NAME','GIT_COMMITTER_NAME','GIT_AUTHOR_EMAIL','GIT_COMMITTER_EMAIL')) {
            $taskIdentityBackup[$taskKey] = [Environment]::GetEnvironmentVariable($taskKey, 'Process')
            $taskIdentityValue = if ($taskKey.EndsWith('_EMAIL')) { 'contributors@example.invalid' } else { 'Journal Citation Audit contributors' }
            [Environment]::SetEnvironmentVariable($taskKey, $taskIdentityValue, 'Process')
        }
        try { Invoke-TaskNative $taskGit @('commit', '-m', 'Publish journal citation audit skill') }
        finally {
            foreach ($taskKey in $taskIdentityBackup.Keys) { [Environment]::SetEnvironmentVariable($taskKey, $taskIdentityBackup[$taskKey], 'Process') }
        }
    }
    if (-not $taskHasOrigin) {
        Invoke-TaskNative $taskGh @('repo', 'create', $taskFullName, '--public', '--description', 'A reusable Codex skill for journal citation audits with selectable publication-date rules.', '--source', $taskRoot, '--remote', 'origin')
    }
    $taskGhShell = $taskGh.Replace('\','/').Replace("'", "'\''")
    $taskHelper = "!'$taskGhShell' auth git-credential"
    Invoke-TaskNative $taskGit @('-c', 'credential.helper=', '-c', "credential.helper=$taskHelper", 'push', '-u', 'origin', 'main')
    $taskResult = & $taskGh repo view $taskFullName --json nameWithOwner,url,visibility
    if ($LASTEXITCODE -ne 0) { throw 'Push completed, but repository verification failed.' }
    Write-Host 'Published successfully:'
    Write-Output $taskResult
}
finally { Pop-Location }
