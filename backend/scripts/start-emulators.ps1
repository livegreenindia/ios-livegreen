# Helper: start Firebase emulators from backend folder and poll functions health
param(
    [int]$pollSeconds = 20
)

$cwd = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $cwd
Write-Output "Starting emulators in $cwd..."
# Start emulators in background
Start-Process -NoNewWindow -FilePath "firebase" -ArgumentList "emulators:start --only functions,firestore,auth" -WorkingDirectory $cwd

Write-Output "Waiting for emulator to initialize (up to $pollSeconds seconds)..."
for ($i=0; $i -lt $pollSeconds; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri 'http://localhost:5001/livegreen-bf838/us-central1/api/health' -UseBasicParsing -TimeoutSec 2
        Write-Output ('Health response: ' + $resp.Content)
        exit 0
    } catch {
        Write-Output ('Attempt ' + $i.ToString() + ': ' + $_.Exception.Message)
        Start-Sleep -Seconds 1
    }
}
Write-Output "Emulator health check did not respond in time. Check emulator terminal for logs."
exit 1
