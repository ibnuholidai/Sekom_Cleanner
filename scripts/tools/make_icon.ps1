# Make Windows .ico from assets/Sekom.png and place it at windows\runner\resources\app_icon.ico
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\tools\make_icon.ps1"

param(
  [string]$InputPng = "assets\Sekom.png",
  [string]$OutputIco = "windows\runner\resources\app_icon.ico"
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath([string]$p) {
  return (Resolve-Path -LiteralPath $p).Path
}

function Ensure-ImageMagick {
  # 1) Check PATH
  $cmd = Get-Command "magick.exe" -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Path
  }

  # 2) Check common install folders (winget/MSI default)
  $roots = @(
    "C:\Program Files\ImageMagick*",
    "C:\Program Files (x86)\ImageMagick*"
  )
  foreach ($root in $roots) {
    try {
      $found = Get-ChildItem -Path $root -Filter "magick.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($found) {
        return $found.FullName
      }
    } catch { }
  }

  # 3) Fallback: download portable ImageMagick
  Write-Host "magick.exe not found in PATH or common folders. Downloading portable ImageMagick..."
  $urls = @(
    "https://imagemagick.org/archive/binaries/ImageMagick-7.1.2-2-Q16-HDRI-x64-dll.zip",
    "https://imagemagick.org/archive/binaries/ImageMagick-7.1.1-25-portable-Q16-x64.zip"
  )
  $zip = Join-Path $env:TEMP "magick-portable.zip"
  $dir = Join-Path $env:TEMP "magick-portable"
  if (Test-Path $zip) { Remove-Item -Force $zip }
  if (Test-Path $dir) { Remove-Item -Force -Recurse $dir }

  $downloaded = $false
  foreach ($u in $urls) {
    try {
      Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing
      $downloaded = $true
      Write-Host "Downloaded: $u"
      break
    } catch {
      Write-Warning "Download failed: $u -> $($_.Exception.Message)"
    }
  }
  if (-not $downloaded) {
    throw "Failed to download portable ImageMagick"
  }

  Expand-Archive -Path $zip -DestinationPath $dir -Force
  $mag = Get-ChildItem -Path $dir -Filter "magick.exe" -Recurse | Select-Object -First 1
  if (-not $mag) {
    throw "magick.exe not found inside portable ImageMagick"
  }
  return $mag.FullName
}

# Ensure inputs
if (-not (Test-Path -LiteralPath $InputPng)) {
  throw "Input PNG not found: $InputPng"
}
$png = Resolve-FullPath $InputPng
$ico = Resolve-FullPath $OutputIco
$icoDir = Split-Path -Parent $ico
if (-not (Test-Path -LiteralPath $icoDir)) {
  New-Item -ItemType Directory -Path $icoDir | Out-Null
}

Write-Host "Source PNG: $png"
Write-Host "Target ICO: $ico"

function Convert-PngToIcoMulti([string]$inputPng,[string]$outputIco,[int[]]$sizes = @(256,128,64,48,32,24,16)) {
  Add-Type -AssemblyName System.Drawing
  $tempFiles = @()
  $images = New-Object System.Collections.Generic.List[byte[]]

  try {
    foreach ($sz in $sizes) {
      $tmp = Join-Path ([System.IO.Path]::GetDirectoryName($outputIco)) ("tmp-icon-$($sz).png")
      $tempFiles += $tmp
      # Resize with high quality
      $src = [System.Drawing.Image]::FromFile($inputPng)
      $bmp = New-Object System.Drawing.Bitmap $sz, $sz
      $g = [System.Drawing.Graphics]::FromImage($bmp)
      $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
      $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
      $g.DrawImage($src, 0, 0, $sz, $sz)
      $g.Dispose()
      $src.Dispose()
      $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
      $bmp.Dispose()

      $bytes = [System.IO.File]::ReadAllBytes($tmp)
      $images.Add($bytes) | Out-Null
    }

    # Write ICO file
    $fs = [System.IO.File]::Open($outputIco, [System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter($fs)

    # ICONDIR
    $bw.Write([UInt16]0)                     # reserved
    $bw.Write([UInt16]1)                     # type (1=icon)
    $bw.Write([UInt16]$sizes.Count)          # count

    # Calculate initial offset: header + entries
    $offset = 6 + (16 * $sizes.Count)

    # Write directory entries
    for ($i=0; $i -lt $sizes.Count; $i++) {
      $sz = $sizes[$i]
      $data = $images[$i]
      # PowerShell 5.1 doesn't support ?: ternary operator; compute explicitly
      $widthByte = 0
      $heightByte = 0
      if ($sz -ne 256) {
        $widthByte = [byte]$sz
        $heightByte = [byte]$sz
      }
      $bw.Write([byte]$widthByte)            # width
      $bw.Write([byte]$heightByte)           # height
      $bw.Write([byte]0)                     # color count
      $bw.Write([byte]0)                     # reserved
      $bw.Write([UInt16]1)                   # planes
      $bw.Write([UInt16]32)                  # bit count
      $bw.Write([UInt32]$data.Length)        # bytes in resource
      $bw.Write([UInt32]$offset)             # offset from beginning
      $offset += $data.Length
    }

    # Write image data blocks
    foreach ($img in $images) {
      $bw.Write($img)
    }

    $bw.Flush()
    $bw.Close()
    $fs.Close()
  }
  finally {
    foreach ($f in $tempFiles) {
      if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
    }
  }
}

# Try ImageMagick, fallback to pure-PS ICO writer if unavailable
$magick = $null
try {
  $magick = Ensure-ImageMagick
} catch {
  Write-Warning "ImageMagick not available, using fallback ICO writer"
  $magick = $null
}

if ($magick) {
  Write-Host "Using magick: $magick"
  & $magick $png -background none -define icon:auto-resize=256,128,64,48,32,24,16 $ico
} else {
  Write-Host "Generating ICO via fallback (multi-size PNG entries 256,128,64,48,32,24,16)..."
  Convert-PngToIcoMulti -inputPng $png -outputIco $ico -sizes @(256,128,64,48,32,24,16)
}

if (-not (Test-Path -LiteralPath $ico)) {
  throw "ICO generation failed: $ico not created"
}

Write-Host "ICO generated at: $ico"
