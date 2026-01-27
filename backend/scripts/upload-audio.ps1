# Upload audio files to Firebase Storage
# Run this script from the backend folder

Write-Host "🎵 Uploading Audio Files to Firebase Storage" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Get Firebase auth token
Write-Host "Getting Firebase authentication token..." -ForegroundColor Yellow
$tokenResult = firebase login:ci 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Not logged in to Firebase. Running firebase login..." -ForegroundColor Red
    firebase login
}

# Audio files to upload
$audioFiles = @(
    @{
        LocalPath = "..\frontend\assets\sounds\Breeze.mp3"
        StoragePath = "audio/Breeze.mp3"
        Description = "Breeze ambiance sound"
    },
    @{
        LocalPath = "..\frontend\assets\sounds\Rain sound.mp3"
        StoragePath = "audio/Rain_sound.mp3"
        Description = "Rain ambiance sound"
    },
    @{
        LocalPath = "..\frontend\assets\sounds\Forest_sound.mp3"
        StoragePath = "audio/Forest_sound.mp3"
        Description = "Forest ambiance sound"
    },
    @{
        LocalPath = "..\frontend\assets\sounds\Guided Body Scan Meditation.mp3"
        StoragePath = "audio/Guided_Body_Scan_Meditation.mp3"
        Description = "Guided meditation voice"
    }
)

$successCount = 0
$failCount = 0

foreach ($file in $audioFiles) {
    $localPath = Join-Path $PSScriptRoot $file.LocalPath
    
    if (-not (Test-Path $localPath)) {
        Write-Host "❌ File not found: $localPath" -ForegroundColor Red
        $failCount++
        continue
    }
    
    $fileSize = (Get-Item $localPath).Length
    $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
    
    Write-Host ""
    Write-Host "📤 Uploading $($file.Description)..." -ForegroundColor Green
    Write-Host "   Local: $localPath" -ForegroundColor Gray
    Write-Host "   Size: $fileSizeMB MB" -ForegroundColor Gray
    Write-Host "   Storage: $($file.StoragePath)" -ForegroundColor Gray
    
    # Use Firebase Storage emulator URL for testing, or deploy to production
    $bucketName = "livegreen-8319e.firebasestorage.app"
    $uploadPath = $file.StoragePath
    
    # Use curl to upload (requires curl to be installed)
    Write-Host "   Uploading via Firebase CLI..." -ForegroundColor Yellow
    
    # Create temp destination in Firebase Storage using firebase storage:upload command
    # This requires firebase-tools with storage upload support
    
    try {
        # For now, just copy files to a local staging area
        # Manual upload: User needs to upload via Firebase Console
        Write-Host "   ⚠️  Please upload manually to Firebase Console:" -ForegroundColor Yellow
        Write-Host "   1. Go to https://console.firebase.google.com/project/livegreen-bf838/storage" -ForegroundColor Cyan
        Write-Host "   2. Create folder 'audio'" -ForegroundColor Cyan
        Write-Host "   3. Upload: $localPath" -ForegroundColor Cyan
        Write-Host "   4. Rename to: $($file.StoragePath.Split('/')[-1])" -ForegroundColor Cyan
        Write-Host ""
        
        $failCount++
    }
    catch {
        Write-Host "❌ Error: $_" -ForegroundColor Red
        $failCount++
    }
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "📊 Summary:" -ForegroundColor Cyan
Write-Host "   ✅ Success: $successCount" -ForegroundColor Green
Write-Host "   ❌ Pending Manual Upload: $failCount" -ForegroundColor Yellow
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Upload audio files manually via Firebase Console" -ForegroundColor White
Write-Host "2. Or use: firebase emulators:start --only storage" -ForegroundColor White
Write-Host "3. Then build app: flutter build appbundle --release" -ForegroundColor White
Write-Host ""
