param([string]$Destination = (Join-Path (Split-Path -Parent $PSScriptRoot) '_downloads'))
$ErrorActionPreference = 'Stop'

$assets = @(
    @{
        Name = 'xovi-aarch64.tar.gz'
        Url = 'https://github.com/asivery/rm-xovi-extensions/releases/download/v19-23052026/xovi-aarch64.tar.gz'
        SHA256 = '32d64d1262ddc984e3235c7d0340a398fe6d5b3efa6a979865f5977b32630d27'
    },
    # AppLoad 0.5.3 hooks the reMarkable OS 3.20 to 3.27 interface and 0.6.0
    # the 3.28 and later one, so the release carries both and the tablet's
    # firmware decides which is installed.
    @{
        Name = 'appload-0.5.3-aarch64.zip'
        Url = 'https://github.com/asivery/rm-appload/releases/download/v0.5.3/appload-aarch64.zip'
        SHA256 = '032e3f2c57a004aba4425894758e4b542c67590efd222e3b3d5141124c45e84d'
    },
    @{
        Name = 'appload-0.6.0-aarch64.tar.gz'
        Url = 'https://github.com/asivery/rm-appload/releases/download/v0.6.0/appload-aarch64.tar.gz'
        SHA256 = '2e7912d15df910631dab847ea5d344081ad75c02a46aaac78bdf731accc53a1f'
    },
    # The 32-bit builds are what the reMarkable 1 and 2 run.
    @{
        Name = 'xovi-arm32.tar.gz'
        Url = 'https://github.com/asivery/rm-xovi-extensions/releases/download/v19-23052026/xovi-arm32.tar.gz'
        SHA256 = '9aa00537ad41e9be0c3151992bfc25106465318cf5bb4c41cf59b3ddd4866377'
    },
    @{
        Name = 'appload-0.5.3-arm32.zip'
        Url = 'https://github.com/asivery/rm-appload/releases/download/v0.5.3/appload-arm32.zip'
        SHA256 = 'dd68c6816c121934da78f59eb497c215e5a9729200de0a8a5bcbeaa5d0aa068b'
    },
    @{
        Name = 'appload-0.6.0-arm32.tar.gz'
        Url = 'https://github.com/asivery/rm-appload/releases/download/v0.6.0/appload-arm32.tar.gz'
        SHA256 = '25aa54735742ea63c0a043cba5496987dd4ca742d8b3fc26a21b7368372bf44f'
    },
    @{
        Name = 'sources/xovi-v0.3.3-source.tar.gz'
        Url = 'https://github.com/asivery/xovi/archive/refs/tags/v0.3.3.tar.gz'
        SHA256 = '2ac3d4ee46851737b8dc6de699073dd612432122f057f1c75c8489678b3fb29f'
    },
    @{
        Name = 'sources/rm-appload-v0.5.3-source.tar.gz'
        Url = 'https://github.com/asivery/rm-appload/archive/refs/tags/v0.5.3.tar.gz'
        SHA256 = 'df5878cf06e1167b9156c2455bab762366d2a4b2058179073734d9ca72e46e94'
    },
    @{
        Name = 'sources/rm-appload-v0.6.0-source.tar.gz'
        Url = 'https://github.com/asivery/rm-appload/archive/refs/tags/v0.6.0.tar.gz'
        SHA256 = 'b00a03107bcbc2c37dde0c5b8a10699bfef31b8d2847b74047ab7fa1507147f1'
    },
    @{
        Name = 'sources/rm-xovi-extensions-v19-source.tar.gz'
        Url = 'https://github.com/asivery/rm-xovi-extensions/archive/refs/tags/v19-23052026.tar.gz'
        SHA256 = '06460210d74779cea287c33ae99408b286908b4bc6c8ae8e9e6b8ca39d19fd80'
    },
    # Redistributed verbatim with the release, so they are pinned like every
    # other fetched artefact rather than trusted at download time. AppLoad
    # 0.6.0 ships the same licence text as 0.5.3 (same SHA-256).
    @{
        Name = 'licenses/XOVI-LICENSE'
        Url = 'https://raw.githubusercontent.com/asivery/xovi/v0.3.3/LICENSE'
        SHA256 = '3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986'
    },
    @{
        Name = 'licenses/APPLOAD-LICENSE'
        Url = 'https://raw.githubusercontent.com/asivery/rm-appload/v0.5.3/LICENSE'
        SHA256 = '3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986'
    },
    @{
        Name = 'licenses/EXTENSIONS-LICENSE'
        Url = 'https://raw.githubusercontent.com/asivery/rm-xovi-extensions/v19-23052026/LICENSE'
        SHA256 = '3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986'
    }
)

New-Item -ItemType Directory -Path $Destination -Force | Out-Null
foreach ($asset in $assets) {
    $path = Join-Path $Destination $asset.Name
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    if (-not (Test-Path -LiteralPath $path) -or (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash -ne $asset.SHA256) {
        Write-Host "Downloading $($asset.Name)..."
        Invoke-WebRequest -UseBasicParsing -Uri $asset.Url -OutFile $path
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    if ($actual -ne $asset.SHA256) { throw "Checksum mismatch for $($asset.Name)" }
}

# AppLoad 0.5.3 was released as ZIPs and 0.6.0 as tarballs; both unpack to
# appload.so and shims/. Windows 10 and later ship bsdtar as tar.exe.
foreach ($archive in @(
    @{ File = 'appload-0.5.3-aarch64.zip'; Out = 'appload-0.5.3-aarch64' },
    @{ File = 'appload-0.5.3-arm32.zip'; Out = 'appload-0.5.3-arm32' },
    @{ File = 'appload-0.6.0-aarch64.tar.gz'; Out = 'appload-0.6.0-aarch64' },
    @{ File = 'appload-0.6.0-arm32.tar.gz'; Out = 'appload-0.6.0-arm32' }
)) {
    $appLoadOut = Join-Path $Destination $archive.Out
    $source = Join-Path $Destination $archive.File
    if (Test-Path -LiteralPath $appLoadOut) { Remove-Item -Recurse -LiteralPath $appLoadOut }
    if ($archive.File.EndsWith('.zip')) {
        Expand-Archive -LiteralPath $source -DestinationPath $appLoadOut
    } else {
        New-Item -ItemType Directory -Path $appLoadOut -Force | Out-Null
        & tar -xzf $source -C $appLoadOut
        if ($LASTEXITCODE -ne 0) { throw "Could not unpack $($archive.File)" }
    }
}

Write-Host "Verified runtime assets are ready in $Destination"
