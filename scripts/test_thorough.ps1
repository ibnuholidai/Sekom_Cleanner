# Sekom Cleaner - Thorough Clean and Verification
# This PowerShell script performs the same thorough cleanup implemented in SystemService.clearRecentFiles()
# plus enhanced Photos unpin/cache cleaning, then runs verification and prints a JSON report.

Set-StrictMode -Off
$ErrorActionPreference = 'SilentlyContinue'

function Remove-PathSafe([string]$Path) {
  try {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (Test-Path -LiteralPath $Path) {
      Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
  } catch {}
}

function Ensure-Dir([string]$Path) {
  try {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (!(Test-Path -LiteralPath $Path)) {
      New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
  } catch {}
}

# Environment
$UserProfile  = $env:USERPROFILE
$AppData      = $env:APPDATA
$LocalAppData = $env:LOCALAPPDATA

# 0) Close common apps
$appsToClose = @(
  'winword','excel','powerpnt','outlook','msaccess','mspub','visio','project',
  'notepad','wordpad'
)
foreach ($p in $appsToClose) { try { Stop-Process -Name $p -Force } catch {} }

# 1) Clear Recent folder (and subfolders)
$recentRoot = Join-Path $AppData 'Microsoft\Windows\Recent'
Remove-PathSafe $recentRoot
Ensure-Dir $recentRoot

# 2) Clear Quick Access jump lists (Auto/Custom)
$autoDest  = Join-Path $recentRoot 'AutomaticDestinations'
$customDest= Join-Path $recentRoot 'CustomDestinations'
Remove-PathSafe $autoDest
Remove-PathSafe $customDest
Ensure-Dir $autoDest
Ensure-Dir $customDest

# 3) Clear Office MRU (multiple versions + apps)
$officeVersions = @('15.0','16.0','17.0','18.0')
$officeApps = @('Word','Excel','PowerPoint','Access','Publisher','Visio','Project')

foreach ($ver in $officeVersions) {
  foreach ($commonKey in @(
    "HKCU:\Software\Microsoft\Office\$ver\Common\Open Find",
    "HKCU:\Software\Microsoft\Office\$ver\Common\Roaming\Open Find",
    "HKCU:\Software\Microsoft\Office\$ver\Common\Place MRU",
    "HKCU:\Software\Microsoft\Office\$ver\Common\Recent Files",
    "HKCU:\Software\Microsoft\Office\$ver\Common\Recent Documents"
  )) { try { Remove-Item -Path $commonKey -Recurse -Force } catch {} }

  foreach ($app in $officeApps) {
    foreach ($k in @(
      "HKCU:\Software\Microsoft\Office\$ver\$app\File MRU",
      "HKCU:\Software\Microsoft\Office\$ver\$app\Place MRU",
      "HKCU:\Software\Microsoft\Office\$ver\$app\User MRU",
      "HKCU:\Software\Microsoft\Office\$ver\$app\Recent Files",
      "HKCU:\Software\Microsoft\Office\$ver\$app\Recent Documents"
    )) { try { Remove-Item -Path $k -Recurse -Force } catch {} }
  }
}

# Office roaming recent links
Remove-PathSafe (Join-Path $AppData 'Microsoft\Office\Recent')
Ensure-Dir     (Join-Path $AppData 'Microsoft\Office\Recent')

# OfficeHub caches
$officeHub = Join-Path $LocalAppData 'Packages\Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe'
Remove-PathSafe (Join-Path $officeHub 'LocalState')
Remove-PathSafe (Join-Path $officeHub 'TempState')

# 4) Clear Windows Search database and app cache + MRU
foreach ($name in @('SearchApp','SearchUI','SearchHost')) {
  try { Stop-Process -Name $name -Force } catch {}
}
try { Stop-Service -Name 'WSearch' -Force } catch {}
Start-Sleep -Seconds 2

Remove-PathSafe (Join-Path $LocalAppData 'Microsoft\Windows\Search')
Remove-PathSafe (Join-Path $LocalAppData 'Packages\Microsoft.Windows.Search_cw5n1h2txyewy\LocalState')

foreach ($rk in @(
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ACMru'
)) { try { Remove-Item -Path $rk -Recurse -Force } catch {} }

try { Start-Service -Name 'WSearch' } catch {}

# 5) Clear Jump Lists again (safety)
Remove-PathSafe $customDest; Ensure-Dir $customDest
Remove-PathSafe $autoDest;   Ensure-Dir $autoDest

# 6) Clear Explorer RecentDocs
try { Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs' -Recurse -Force } catch {}

# 7-10) Other app recents
try { Remove-Item -Path 'HKCU:\Software\Microsoft\Notepad' -Name 'Recent File List' -Force } catch {}
try { Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Wordpad\Recent File List' -Recurse -Force } catch {}
try { Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Paint\Recent File List' -Recurse -Force } catch {}
try { Remove-Item -Path 'HKCU:\Software\Microsoft\MediaPlayer\Player\RecentFileList' -Recurse -Force } catch {}
try { Remove-Item -Path 'HKCU:\Software\Microsoft\MediaPlayer\Player\RecentURLList' -Recurse -Force } catch {}

# 11) Photo Viewer recents
try { Remove-Item -Path 'HKCU:\Software\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations' -Recurse -Force } catch {}

# 12) Start Menu old history
Remove-PathSafe (Join-Path $LocalAppData 'Microsoft\Windows\History\History.IE5')

# 13) Explorer address bar URLs
try { Remove-Item -Path 'HKCU:\Software\Microsoft\Internet Explorer\TypedURLs' -Recurse -Force } catch {}

# 14) Thumbnail cache
$thumbDir = Join-Path $LocalAppData 'Microsoft\Windows\Explorer'
if (Test-Path $thumbDir) {
  Get-ChildItem -LiteralPath $thumbDir -Filter 'thumbcache*.db' -ErrorAction SilentlyContinue | ForEach-Object {
    try { Remove-Item -LiteralPath $_.FullName -Force } catch {}
  }
}

# Photos: unpin + cache cleanup
foreach ($p in @('Microsoft.Photos','PhotosApp','msphotos')) { try { Stop-Process -Name $p -Force } catch {} }

$photosPkg = Join-Path $LocalAppData 'Packages\Microsoft.Windows.Photos_8wekyb3d8bbwe'
Remove-PathSafe (Join-Path $photosPkg 'LocalState')
Remove-PathSafe (Join-Path $photosPkg 'LocalCache')
Remove-PathSafe (Join-Path $photosPkg 'TempState')

# Remove Photos pinned shortcuts from StartMenu "User Pinned"
$startPinned = Join-Path $AppData 'Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu'
if (Test-Path $startPinned) {
  Get-ChildItem -LiteralPath $startPinned -Filter '*.lnk' -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match 'Photos' -or $_.Name -match 'Microsoft Photos'
  } | ForEach-Object {
    try { Remove-Item -LiteralPath $_.FullName -Force } catch {}
  }
}

# Unpin Photos via COM (best-effort)
try {
  $shell = New-Object -ComObject Shell.Application
  $appsFolder = $shell.NameSpace('shell:AppsFolder')
  if ($appsFolder) {
    $photosApp = $appsFolder.Items() | Where-Object {
      $_.Name -like '*Photos*' -or
      $_.Path -like '*Microsoft.Windows.Photos*' -or
      $_.Path -eq 'Microsoft.Windows.Photos_8wekyb3d8bbwe!App'
    }
    if ($photosApp) {
      $photosApp | ForEach-Object {
        $verbs = $_.Verbs()
        $unpinVerb = $verbs | Where-Object {
          $_.Name -like '*Unpin*' -or
          $_.Name -like '*Lepas*' -or
          $_.Name -match 'Unpin from Start' -or
          $_.Name -match 'Lepas.*Start'
        }
        if ($unpinVerb) { try { $unpinVerb.DoIt() } catch {} }
      }
    }
  }
} catch {}

# Clear Start cloud cache and Start host LocalState (to remove stale tiles)
try { reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount" /f | Out-Null } catch {}
foreach ($proc in @('StartMenuExperienceHost','ShellExperienceHost','SearchHost')) { try { Stop-Process -Name $proc -Force } catch {} }
$startHostPath = Join-Path $LocalAppData 'Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState'
Remove-PathSafe $startHostPath

# Restart Explorer and refresh icons
try { Stop-Process -Name explorer -Force } catch {}
Start-Sleep -Seconds 1
try { Start-Process explorer.exe } catch {}
try { ie4uinit.exe -show | Out-Null } catch {}

# Build verification report
$report = [ordered]@{}

# Recent folders counts
$report.RecentCount              = (Get-ChildItem -LiteralPath $recentRoot -Force -ErrorAction SilentlyContinue | Measure-Object).Count
$report.JumpListAutoCount        = (Get-ChildItem -LiteralPath $autoDest -Force -ErrorAction SilentlyContinue | Measure-Object).Count
$report.JumpListCustomCount      = (Get-ChildItem -LiteralPath $customDest -Force -ErrorAction SilentlyContinue | Measure-Object).Count

# Office roaming recent
$officeRecentPath = Join-Path $AppData 'Microsoft\Office\Recent'
$report.OfficeRecentFolderExists = (Test-Path -LiteralPath $officeRecentPath)
$report.OfficeRecentCount        = if ($report.OfficeRecentFolderExists) { (Get-ChildItem -LiteralPath $officeRecentPath -Force -ErrorAction SilentlyContinue | Measure-Object).Count } else { 0 }

# MRU keys existence after deletion (should be False for most)
$keysToCheck = @(
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSaveMRU',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs'
)
$existsMap = @{}
foreach ($k in $keysToCheck) {
  $existsMap[$k] = Test-Path -Path $k
}
$report.RegistryKeysExist = $existsMap

# Start pinned Photos .lnk remaining
$report.PhotosPinnedLinks = if (Test-Path $startPinned) {
  (Get-ChildItem -LiteralPath $startPinned -Filter '*.lnk' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Photos' -or $_.Name -match 'Microsoft Photos' } | Measure-Object).Count
} else { 0 }

# Photos cache folder presence
$report.PhotosPackageExists = Test-Path -LiteralPath $photosPkg
$report.PhotosLocalState    = Test-Path -LiteralPath (Join-Path $photosPkg 'LocalState')
$report.PhotosLocalCache    = Test-Path -LiteralPath (Join-Path $photosPkg 'LocalCache')
$report.PhotosTempState     = Test-Path -LiteralPath (Join-Path $photosPkg 'TempState')

# Thumbnail cache DB files
$report.ThumbCacheDbCount   = if (Test-Path $thumbDir) { (Get-ChildItem -LiteralPath $thumbDir -Filter 'thumbcache*.db' -ErrorAction SilentlyContinue | Measure-Object).Count } else { 0 }

# Windows Search db exists after restart (it may be re-created empty)
$searchDbPath = Join-Path $LocalAppData 'Microsoft\Windows\Search'
$report.SearchDbExists      = Test-Path -LiteralPath $searchDbPath

# Output report JSON
$report | ConvertTo-Json -Compress
