param(
  [string]$apiBase = 'http://127.0.0.1:5001/livegreen-bf838/us-central1/api',
  [int]$port = 8081
)
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
  $frontendRoot = Join-Path $scriptDir ".."
  Set-Location (Resolve-Path $frontendRoot)
Write-Output "Starting Flutter web with API_BASE_URL=$apiBase on port $port"
  Write-Output "Starting Flutter web with API_BASE_URL=$apiBase on port $port in $(Get-Location)"
Start-Process -NoNewWindow -FilePath 'cmd' -ArgumentList "/c flutter run -d chrome --web-port=$port --web-hostname=localhost --dart-define=API_BASE_URL='$apiBase'" -WorkingDirectory (Get-Location)
