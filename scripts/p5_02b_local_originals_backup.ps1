# P5-02B: audit, copy and independently verify PC-only original art.
# Does NOT upload anything, use Git remotes, delete sources or overwrite backups.
[CmdletBinding()]
param(
    [ValidateSet('Audit', 'Backup', 'Verify')]
    [string]$Mode = 'Audit',
    [string]$RawAssetsPath = 'D:\Workspace\Games\necromancer-and-dice\raw_assets',
    [string]$SourceAssetsPath = 'C:\Dev\necromancer_and_dice\source_assets',
    [string[]]$AdditionalSourcePaths = @(),
    [string]$DestinationRoot = '',
    [switch]$AllowSameVolume
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:excluded = New-Object 'System.Collections.Generic.List[string]'
$script:items = New-Object 'System.Collections.Generic.List[object]'
$script:sources = New-Object 'System.Collections.Generic.List[object]'
$script:cmp = [System.StringComparison]::OrdinalIgnoreCase

function Assert-Condition([bool]$valid, [string]$reason) {
    if (-not $valid) { throw "P5_02B_FAIL: $reason" }
}
function Full-Path([string]$value) {
    return [System.IO.Path]::GetFullPath($value).TrimEnd([char[]]@('\','/'))
}
function Is-Under([string]$candidate, [string]$parent) {
    $a = (Full-Path $candidate) + [IO.Path]::DirectorySeparatorChar
    $b = (Full-Path $parent) + [IO.Path]::DirectorySeparatorChar
    return $a.StartsWith($b, $script:cmp)
}
function Is-Unsafe([string]$relative) {
    $name = $relative.Replace('\','/')
    # Never copy keys, local saves, repository internals or engine caches.
    return ($name -match '(?i)(^|/)(\.git|\.godot|\.ssh|\.aws|node_modules|__pycache__|\.venv|builds?|test-results)(/|$)' -or
            $name -match '(?i)(^|/)(\.env(?:\.[^/]*)?|\.npmrc|\.pypirc|id_rsa|id_ed25519|credentials(?:\.[^/]*)?|secrets?\.(?:json|ya?ml)|[^/]+\.(?:pem|p12|pfx|key|sqlite|db))$')
}
function Add-Root([string]$label, [string]$path, [bool]$required) {
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        if ($required) { throw "P5_02B_FAIL: required source missing: $label" }
        Write-Host "P5_02B_SOURCE_ABSENT: $label"
        return
    }
    $full = Full-Path (Resolve-Path -LiteralPath $path).Path
    Assert-Condition ($full -ne [IO.Path]::GetPathRoot($full).TrimEnd([char[]]@('\','/'))) "drive/root folders cannot be backed up"
    foreach ($old in $script:sources) {
        Assert-Condition (-not (Is-Under $full $old.Path) -and -not (Is-Under $old.Path $full)) "overlapping source trees ($label and $($old.Label))"
    }
    $script:sources.Add([pscustomobject]@{ Label=$label; Path=$full })
}
function Get-Entries {
    foreach ($source in $script:sources) {
        $stack = New-Object System.Collections.Stack
        $stack.Push($source.Path)
        while ($stack.Count -gt 0) {
            $folder = [string]$stack.Pop()
            foreach ($entry in @(Get-ChildItem -LiteralPath $folder -Force -ErrorAction Stop)) {
                $relative = $entry.FullName.Substring($source.Path.Length).TrimStart([char[]]@('\','/'))
                $key = $source.Label + '/' + $relative.Replace('\','/')
                if (Is-Unsafe $relative) {
                    $script:excluded.Add("EXCLUDED:$key")
                    continue
                }
                if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                    $script:excluded.Add("SYMLINK_OR_JUNCTION:$key")
                    continue
                }
                if ($entry.PSIsContainer) {
                    $stack.Push($entry.FullName)
                    continue
                }
                # A file might change during a copy. Re-hash source after
                # copying, and abort if it no longer matches the first hash.
                $script:items.Add([pscustomobject]@{
                    Relative=$key; Source=$entry.FullName; Bytes=[long]$entry.Length
                })
            }
        }
    }
}
function Validate-Copy([string]$root, [bool]$requireComplete) {
    $manifestPath = Join-Path $root 'manifest.json'
    $hashPath = Join-Path $root 'manifest.sha256'
    Assert-Condition (Test-Path -LiteralPath $manifestPath -PathType Leaf) "backup manifest is missing"
    Assert-Condition (Test-Path -LiteralPath $hashPath -PathType Leaf) "manifest checksum is missing"
    if ($requireComplete) {
        Assert-Condition (Test-Path -LiteralPath (Join-Path $root 'BACKUP_COMPLETE') -PathType Leaf) "backup is incomplete"
        Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $root 'BACKUP_INCOMPLETE'))) "incomplete marker exists"
    }
    $expectedManifestHash = (Get-Content -LiteralPath $hashPath -Raw).Trim()
    $actualManifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-Condition ($actualManifestHash -eq $expectedManifestHash) "manifest SHA256 mismatch"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    Assert-Condition ($manifest.Version -eq 1) "unsupported manifest version"
    $entries = @($manifest.Files)
    Assert-Condition ($entries.Count -gt 0) "no archived source files"
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $sum = [long]0
    foreach ($file in $entries) {
        $relative = [string]$file.Relative
        Assert-Condition ($relative -notmatch '(^/|^\.\.|/\.\./|\\|:)' -and $relative -like '*/*') "invalid manifest-relative path"
        Assert-Condition ($seen.Add($relative)) "duplicate backup file path: $relative"
        $target = Join-Path $root ('files/' + $relative.Replace('/', [IO.Path]::DirectorySeparatorChar))
        Assert-Condition (Is-Under $target (Join-Path $root 'files')) "backup file escapes backup root"
        Assert-Condition (Test-Path -LiteralPath $target -PathType Leaf) "missing backup file: $relative"
        $info = Get-Item -LiteralPath $target
        Assert-Condition (-not (($info.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) "backup link is disallowed: $relative"
        Assert-Condition ([long]$info.Length -eq [long]$file.Bytes) "backup size mismatch: $relative"
        $actual = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert-Condition ($actual -eq [string]$file.Sha256) "backup hash mismatch: $relative"
        $sum += [long]$info.Length
    }
    $actualFiles = @(Get-ChildItem -LiteralPath (Join-Path $root 'files') -File -Recurse -Force)
    Assert-Condition ($actualFiles.Count -eq $entries.Count) "unexpected extra files in backup"
    Assert-Condition ($sum -eq [long]$manifest.Bytes) "total size mismatch"
    Write-Host "P5_02B_VERIFIED: $($entries.Count) files, $sum bytes, SHA256 all matched; $(@($manifest.Excluded).Count) excluded paths need review"
    return $manifest
}

if ($Mode -eq 'Verify') {
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($DestinationRoot)) "supply -DestinationRoot"
    $dest = Full-Path $DestinationRoot
    Assert-Condition (Test-Path -LiteralPath $dest -PathType Container) "backup directory missing"
    $null = Validate-Copy $dest $true
    exit 0
}

Add-Root 'raw_assets' $RawAssetsPath $false
Add-Root 'source_assets' $SourceAssetsPath $false
for ($i=0; $i -lt $AdditionalSourcePaths.Count; $i++) {
    Add-Root ("additional_" + ($i+1)) $AdditionalSourcePaths[$i] $true
}
Assert-Condition ($script:sources.Count -gt 0) "no accessible original source directories; provide correct PC paths"
Get-Entries
$files = @($script:items | Sort-Object Relative)
$total = [long]0
foreach ($file in $files) { $total += [long]$file.Bytes }
Write-Host "P5_02B_INVENTORY: $($script:sources.Count) roots, $($files.Count) files, $total bytes, $($script:excluded.Count) excluded/symlink entries"
foreach ($root in $script:sources) {
    $count = @($files | Where-Object { $_.Relative.StartsWith($root.Label + '/') }).Count
    Write-Host "P5_02B_ROOT: $($root.Label) files=$count"
}
if ($Mode -eq 'Audit') { exit 0 }

Assert-Condition (-not [string]::IsNullOrWhiteSpace($DestinationRoot)) "Backup requires -DestinationRoot (new backup directory on independently owned storage)"
Assert-Condition ($files.Count -gt 0) "all sources empty; refusing empty backup"
$dest = Full-Path $DestinationRoot
Assert-Condition (-not (Test-Path -LiteralPath $dest)) "backup destination already exists; never overwrite an archive"
$repoRoot = Full-Path (Join-Path $PSScriptRoot '..')
Assert-Condition (-not (Is-Under $dest $repoRoot)) "cannot back up into the public Godot working tree"
foreach ($source in $script:sources) {
    Assert-Condition (-not (Is-Under $dest $source.Path) -and -not (Is-Under $source.Path $dest)) "destination overlaps source tree"
    if (-not $AllowSameVolume) {
        $sourceDrive = [IO.Path]::GetPathRoot($source.Path)
        $targetDrive = [IO.Path]::GetPathRoot($dest)
        Assert-Condition ($sourceDrive -ne $targetDrive) "backup on same volume as $($source.Label); use an external drive or -AllowSameVolume only for an unapproved staging copy"
    }
}
$null = New-Item -ItemType Directory -Path $dest -ErrorAction Stop
Set-Content -LiteralPath (Join-Path $dest 'BACKUP_INCOMPLETE') -Value 'Incomplete until independently verified. Never treat this folder as approved.' -Encoding UTF8
$written = New-Object 'System.Collections.Generic.List[object]'
foreach ($file in $files) {
    $target = Join-Path $dest ('files/' + $file.Relative.Replace('/', [IO.Path]::DirectorySeparatorChar))
    $parent = Split-Path -Path $target -Parent
    $null = New-Item -ItemType Directory -Path $parent -Force
    Assert-Condition (-not (Test-Path -LiteralPath $target)) "backup target collision"
    $sourceHashBefore = (Get-FileHash -LiteralPath $file.Source -Algorithm SHA256).Hash.ToLowerInvariant()
    Copy-Item -LiteralPath $file.Source -Destination $target -ErrorAction Stop
    $sourceHashAfter = (Get-FileHash -LiteralPath $file.Source -Algorithm SHA256).Hash.ToLowerInvariant()
    $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-Condition ($sourceHashBefore -eq $sourceHashAfter -and $sourceHashAfter -eq $targetHash) "original changed during backup or copy mismatch: $($file.Relative)"
    $destSize = (Get-Item -LiteralPath $target).Length
    Assert-Condition ($destSize -eq $file.Bytes) "original size changed while copying"
    $written.Add([pscustomobject]@{ Relative=$file.Relative; Bytes=[long]$destSize; Sha256=$targetHash })
}
$manifest = [ordered]@{
    Version = 1
    CreatedUtc = [DateTime]::UtcNow.ToString('o')
    SameVolumeOverride = [bool]$AllowSameVolume
    Roots = @($script:sources | ForEach-Object { [pscustomobject]@{ Label=$_.Label; Path=$_.Path } })
    Files = @($written)
    Bytes = $total
    Excluded = @($script:excluded)
    Note = 'PC-only originals: local offline copy. Never commit this manifest or asset folder to public GitHub. Review excluded paths; another physically separate copy is required.'
}
$manifestPath = Join-Path $dest 'manifest.json'
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
$manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $dest 'manifest.sha256'), $manifestHash + [Environment]::NewLine)
$null = Validate-Copy $dest $false
Remove-Item -LiteralPath (Join-Path $dest 'BACKUP_INCOMPLETE') -ErrorAction Stop
[IO.File]::WriteAllText((Join-Path $dest 'BACKUP_COMPLETE'), "SHA256_VERIFIED " + [DateTime]::UtcNow.ToString('o'))
Write-Host "P5_02B_BACKUP_COMPLETE: backup independently verified; sources untouched. Keep manifest private."
Write-Host "P5_02B_NEXT: run -Mode Verify against this destination after unplug/reconnect; add a second separate-device backup and PC evidence before marking P5-02B DONE."
