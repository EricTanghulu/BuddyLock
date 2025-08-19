# BuddyLock (iOS, SwiftUI)

**BuddyLock** is an iOS app designed to help people reclaim focus by combining **screen-time limits** with **friend accountability**. Instead of managing digital wellbeing alone, BuddyLock brings in your accountability circle to keep you motivated and on track.

---

## ✨ Features

- **Screen Time Integration**  
  Built on Apple’s iOS 16+ Screen Time APIs (Family Controls, Managed Settings, Device Activity).

- **Family Activity Picker**  
  Select apps, categories, and websites to shield with a few taps.

- **Shields & Focus Sessions**  
  Instantly block distracting apps or set a time-boxed focus period that ends automatically.

- **Customizable Shield UI**  
  Sample extension that can show “Ask a Friend” when you attempt to open a blocked app.

- **Device Activity Monitoring**  
  Example extension for scheduling recurring app limits and reporting usage.

- **Buddy Approval Stub**  
  Protocol placeholder for integrating CloudKit, Firebase, or another backend to enable real-time friend approvals.

---

## 🚀 Getting Started

### Prerequisites
- macOS with **Xcode 15+**
- iOS device or simulator running **iOS 16+**
- An Apple Developer Account (required for Family Controls capability)

### Installation
```bash
git clone https://github.com/<your-username>/BuddyLock.git
cd BuddyLock
open BuddyLock.xcodeproj
```

### Setup in Xcode
1. Open the **BuddyLock** project in Xcode.
2. Enable **Signing & Capabilities**:
   - Add **Family Controls**
   - Add **App Groups** (e.g., `group.com.yourcompany.buddylock`)
3. Build & run on a simulator or device.
4. Tap **Request Screen Time Permission** inside the app.
5. Use the **Family Activity Picker** to choose apps/categories.
6. Toggle **Activate shield now** or start a **Focus Session**.

---

## 📂 Project Structure

- `BuddyLockApp.swift` — App entry point  
- `ContentView.swift` — Main UI for managing shields & sessions  
- `ScreenTimeManager.swift` — Core logic for authorization and shielding  
- `Extensions/ShieldUIExtensionSample.swift` — Sample custom overlay  
- `Extensions/DeviceActivityMonitorExtension/MonitorSample.swift` — Example monitor extension  
- `Services/BuddyApprovalService.swift` — Protocol for future buddy integrations  

---

## 🛠 Roadmap

- 🔗 Backend for **real-time friend approvals**  
- 📲 Push notifications for unlock requests  
- 👥 Group challenges & focus rooms  
- 💻 Cross-device sync and analytics  

---

## 🤝 Contributing

Contributions are welcome!  
- Fork the repo and create a feature branch.  
- Submit a pull request with a clear description.  
- For major changes, please open an issue first to discuss.  

---

## 📜 License

This project is licensed under the MIT License
