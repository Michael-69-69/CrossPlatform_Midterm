Write-Host "🔧 Fixing Android build issues..." -ForegroundColor Green

Write-Host ""
Write-Host "1. Cleaning Flutter project..." -ForegroundColor Yellow
flutter clean

Write-Host ""
Write-Host "2. Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host ""
Write-Host "3. Cleaning Android build..." -ForegroundColor Yellow
Set-Location android
./gradlew clean
Set-Location ..

Write-Host ""
Write-Host "4. Running Flutter app..." -ForegroundColor Yellow
flutter run

Write-Host ""
Write-Host "✅ Build fixes applied!" -ForegroundColor Green
Write-Host ""
Write-Host "If you still get errors, try:" -ForegroundColor Cyan
Write-Host "- flutter doctor" -ForegroundColor White
Write-Host "- flutter pub deps" -ForegroundColor White
Write-Host "- Check Android Studio SDK settings" -ForegroundColor White


