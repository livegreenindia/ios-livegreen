Param(
  [string]$Out = "livegreen_backend.zip"
)
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "Creating package $Out from $root"
if (Test-Path $Out) { Remove-Item $Out }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($root, $Out)
Write-Host "Package created: $Out"
