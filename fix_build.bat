@echo off
echo 🔧 Fixing Android build issues...

echo.
echo 1. Cleaning Flutter project...
flutter clean

echo.
echo 2. Getting Flutter dependencies...
flutter pub get

echo.
echo 3. Cleaning Android build...
cd android
./gradlew clean
cd ..

echo.
echo 4. Running Flutter app...
flutter run

echo.
echo ✅ Build fixes applied!
echo.
echo If you still get errors, try:
echo - flutter doctor
echo - flutter pub deps
echo - Check Android Studio SDK settings


