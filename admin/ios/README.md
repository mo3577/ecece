# iOS (build on a Mac)

This folder is the Xcode / CocoaPods project for **ECE Admin**.  
Clone the repo on a **Mac** with Xcode + Flutter, then:

```bash
cd admin
flutter pub get
cd ios && pod install && cd ..

# Device plugged in, Developer Mode on:
flutter devices
flutter run -d <your-iphone-id>

# Or open in Xcode (pick your Team for signing):
open ios/Runner.xcworkspace
```

Bundle ID: `edu.ece.eceAdmin`  
Display name: ECE Admin  

Local network + HTTP to the kiosk are already allowed in `Runner/Info.plist` (UDP discovery + PocketBase on LAN).
