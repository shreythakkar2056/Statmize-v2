# PowerShell script to get SHA-1 certificate fingerprint for Android

Write-Host "Getting SHA-1 certificate fingerprint for Android..." -ForegroundColor Green

# Check if keytool is available
try {
    $keytoolVersion = keytool -version 2>&1
    Write-Host "✓ Keytool found" -ForegroundColor Green
}
catch {
    Write-Host "✗ Keytool not found. Please install Java JDK and add it to PATH" -ForegroundColor Red
    exit 1
}

# Get debug keystore path
$debugKeystorePath = "$env:USERPROFILE\.android\debug.keystore"

if (Test-Path $debugKeystorePath) {
    Write-Host ""
    Write-Host "Found debug keystore at: $debugKeystorePath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "SHA-1 Certificate Fingerprint (Debug):" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    keytool -list -v -keystore $debugKeystorePath -alias androiddebugkey -storepass android -keypass android | Select-String "SHA1"

    Write-Host ""
    Write-Host "Use this SHA-1 fingerprint in Google Cloud Console for Android OAuth 2.0 Client ID" -ForegroundColor Green
}
else {
    Write-Host "Debug keystore not found at: $debugKeystorePath" -ForegroundColor Red
    Write-Host "This is normal if you haven't run the app yet." -ForegroundColor Yellow
    Write-Host "Run 'flutter run' once to generate the debug keystore, then run this script again." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "For release builds, use your release keystore:" -ForegroundColor Yellow
Write-Host "keytool -list -v -keystore your-release-key.keystore -alias your-key-alias" -ForegroundColor Gray
