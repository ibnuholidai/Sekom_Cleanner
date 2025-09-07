# Build Inno Setup installer for sekom_clenner
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\installer\build_installer.ps1"

$ErrorActionPreference = 'Stop'

Write-Host "==> Downloading Inno Setup installer..."
$urls = @(
  'https://files.jrsoftware.org/is/6/innosetup-6.3.3.exe',
  'https://jrsoftware.org/download.php/is.exe'
)
$dst = Join-Path $env:TEMP 'innosetup.exe'
$downloaded = $false
foreach ($u in $urls) {
  try {
    Invoke-WebRequest -Uri $u -OutFile $dst -UseBasicParsing
    $downloaded = $true
    Write-Host "   Downloaded from $u"
    break
  }
  catch {
    Write-Warning ("   Download failed from {0}: {1}" -f $u, $_.Exception.Message)
  }
}
if (-not $downloaded) {
  throw "Failed to download Inno Setup installer"
}

Write-Host "==> Installing Inno Setup silently..."
$proc = Start-Process -FilePath $dst -ArgumentList '/VERYSILENT','/NORESTART','/SP-' -PassThru -Wait
Write-Host "   Inno Setup installer exit code: $($proc.ExitCode)"

# Try to locate ISCC.exe
$isccPaths = @(
  'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
  'C:\Program Files\Inno Setup 6\ISCC.exe'
)
$ISCC = $null
foreach ($p in $isccPaths) {
  if (Test-Path $p) {
    $ISCC = $p
    break
  }
}
if (-not $ISCC) {
  throw "ISCC.exe not found after installation. Please ensure Inno Setup 6 is installed."
}
Write-Host "==> Found ISCC at: $ISCC"

# Path to .iss script relative to this script directory
$iss = Join-Path $PSScriptRoot 'sekom_clenner.iss'
if (-not (Test-Path $iss)) {
  throw "ISS script not found at: $iss"
}
Write-Host "==> ISS script: $iss"

# Ensure Flutter Windows Release build exists
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
if (-not (Test-Path $releaseDir)) {
  throw "Release folder not found: $releaseDir. Run 'flutter build windows --release' first."
}
Write-Host "==> Release folder OK: $releaseDir"

# Compile installer
Write-Host "==> Compiling installer with ISCC..."
& $ISCC $iss
$exit = $LASTEXITCODE
Write-Host "==> ISCC exit code: $exit"
exit $exit
