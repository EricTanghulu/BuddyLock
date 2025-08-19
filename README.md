# BuddyLock Starter (iOS, SwiftUI)

**BuddyLock** is an iOS app that helps people reclaim their time by combining **screen-time limits** with **social accountability**. Instead of managing limits alone, BuddyLock lets your friends (or accountability partners) play an active role in keeping you focused.

This repo is a **starter project** showcasing how to use Apple’s Screen Time APIs (Family Controls, Managed Settings, and Device Activity) to build a socially-driven digital wellbeing app.

---

## ✨ Features

- **Screen Time Integration**  
  Requests iOS 16+ permission to manage app & domain limits.

- **Family Activity Picker**  
  Choose which apps, categories, and websites to shield.

- **Shields & Focus Sessions**  
  Block apps immediately or run time-boxed focus sessions that end automatically.

- **Customizable Shield UI**  
  Sample extension that can display “Ask a Friend” or “Not Now” when a user tries to open a blocked app.

- **Device Activity Monitor**  
  Example extension for scheduling daily/weekly screen-time challenges.

- **Buddy Approval Service (stub)**  
  A protocol stub for implementing friend-based approvals with CloudKit, Firebase, or any backend of your choice.

---

## 🚀 Getting Started

### Prerequisites
- macOS with **Xcode 15+**
- An iOS device or simulator running **iOS 16+**
- A free or paid **Apple Developer Account** (needed to enable Family Controls capability)

### Installation
```bash
git clone https://github.com/<your-username>/BuddyLockStarter.git
cd BuddyLockStarter
open BuddyLockStarter.xcodeproj
```

### Setup in Xcode
1. Enable **Signing & Capabilities**:
   - Add **Family Controls**
   - Add **App Groups** (e.g., `group.com.yourcompany.buddylock`)
2. Build & run on a simulator or device.
3. Tap **Request Screen Time Permission** inside the app.
4. Use the **Family Activity Picker** to choose apps/categories.
5. Toggle **Activate shield now** or start a **Focus Session**.

---

## 📂 Project Structure

- `BuddyLockStarterApp.swift` — App entry point  
- `ContentView.swift` — Main UI (authorization, shields, focus sessions)  
- `ScreenTimeManager.swift` — Handles authorization & shield logic  
- `Extensions/ShieldUIExtensionSample.swift` — Custom shield overlay (Ask a Friend)  
- `Extensions/DeviceActivityMonitorExtension/MonitorSample.swift` — Monitor for scheduled activity  
- `Services/BuddyApprovalService.swift` — Protocol stub for friend approvals  

---

## 🛠 Roadmap

- Backend integration for real-time **friend approvals**  
- Push notifications for unlock requests  
- Team challenges & focus rooms  
- Cross-device sync  

---

## 🤝 Contributing

Contributions are welcome!  
- Fork the repo and create a feature branch.  
- Submit a pull request with a clear description.  
- For large features, please open an issue first to discuss the approach.  

---

## 📜 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

### 🙌 Acknowledgements
Built with ❤️ using Apple’s [Family Controls](https://developer.apple.com/documentation/familycontrols), [Managed Settings](https://developer.apple.com/documentation/managedsettings), and [Device Activity](https://developer.apple.com/documentation/deviceactivity) frameworks.
