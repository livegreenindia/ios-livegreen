# Poll functions health endpoint until it responds or timeout
param(
    [int]$maxAttempts = 30,
    [int]$delaySeconds = 1
)
for ($i = 0; $i -lt $maxAttempts; $i++) {
    try {
        $r = Invoke-WebRequest -Uri 'http://localhost:5001/livegreen-bf838/us-central1/api/health' -UseBasicParsing -TimeoutSec 3
        Write-Output "SUCCESS: $($r.StatusCode) - $($r.Content)"
        exit 0
    } catch {
        Write-Output ("Attempt {0}/{1}: {2}" -f ($i+1), $maxAttempts, $_.Exception.Message)
        Start-Sleep -Seconds $delaySeconds
    }
}
Write-Output "Timed out waiting for functions health endpoint."
exit 1
