
# BuddyLock Starter (iOS, SwiftUI)

A minimal, compile-ready Xcode project to start building your friend‑accountable screen‑time app.

This starter includes:
- ✅ A SwiftUI iOS app target you can run in the simulator
- ✅ A `ScreenTimeManager` wrapper that requests authorization and applies **shields** for selected apps/categories (if the Family Controls APIs are available)
- ✅ A UI with **Request Authorization**, **Family Activity Picker**, and **Focus Session** (timeboxed shield)
- ✅ Sample source for a **Shield UI Extension** (Ask a Friend) and a **Device Activity Monitor Extension** — provided as code *samples* you can add as separate targets in Xcode
- ✅ An entitlements template and App Group placeholder
- ✅ A protocol stub for buddy approvals (so you can plug in CloudKit/Firebase/etc.)

> **Note:** Using Screen Time APIs in a shipping app requires the **Family Controls** capability. You add this in Xcode **Signing & Capabilities**. If you don’t add it yet, the app still builds and the UI works; API calls will simply be no‑ops.

---

## Quick start

1. **Open the project**
   - Open `BuddyLockStarter/BuddyLockStarter.xcodeproj` in Xcode (iOS 16+ SDK).
   - Select an iPhone simulator and **Run**. The app builds without extra setup.

2. **(Recommended) Enable capabilities**
   - Go to your app target → **Signing & Capabilities**.
   - Add **App Groups** and create something like `group.com.<yourcompany>.buddylock`. Update it here and in your extensions later.
   - Add **Family Controls** (this adds the `com.apple.developer.family-controls` entitlement).

3. **Try the flow**
   - Tap **Request Screen Time Permission** (authorizes as `.individual`).
   - Tap **Open Family Activity Picker**, choose a few apps/categories.
   - Toggle **Activate shield now** or start a **Focus session**. When you open a chosen app in the simulator, iOS will show the default shield overlay. To customize and add “Ask a Friend,” add the extension below.

---

## Add the Shield UI Extension (custom overlay)

1. In Xcode: **File → New → Target… → Managed Settings UI Extension**.
2. Name it `ShieldUIExtension` and check **Include UI Extension**.
3. In the new target, **replace** the template code with the sample in `Extensions/ShieldUIExtension/ShieldUIExtensionSample.swift`.
4. Add **App Groups** and **Family Controls** capabilities to the extension target too.
5. Build & run the main app again. Opening a shielded app now shows your custom overlay with **Ask a Friend** (which currently calls `.defer`).

> `.defer` lets you pause while your main app asks a buddy. When an approval arrives, remove the shield for the selected app(s) using `ManagedSettingsStore`.

---

## Add the Device Activity Monitor Extension (optional)

1. **File → New → Target… → Device Activity Monitor Extension**.
2. Replace its content with `Extensions/DeviceActivityMonitorExtension/MonitorSample.swift`.
3. Use this to schedule windows and react to thresholds.

---

## Where to put your “buddy approvals”

Implement `BuddyApprovalService` (in `Services/`) with your backend of choice:
- Send a push / in-app notification to a buddy when a shielded app is opened.
- If they approve for **N minutes**, your app removes the relevant shields and starts a timer to re‑apply when time expires.
- If they deny or timeout, keep the shields as-is.

---

## Files of interest

- `BuddyLockStarterApp.swift` — App entry point
- `ContentView.swift` — UI demonstrating authorization, picker, and focus sessions
- `ScreenTimeManager.swift` — Thin wrapper over `AuthorizationCenter` and `ManagedSettingsStore`
- `Extensions/ShieldUIExtension/ShieldUIExtensionSample.swift` — Custom shield UI with “Ask a Friend”
- `Extensions/DeviceActivityMonitorExtension/MonitorSample.swift` — Scheduled blocks (optional)
- `BuddyLockStarter.entitlements` — Template entitlements (not wired until you add capabilities)
- `Assets.xcassets` — App icon placeholder (fine for Simulator)

---

## Notes & caveats

- You must run on **iOS 16+** for Family Controls APIs.
- The project compiles *without* the capability enabled, thanks to `#if canImport(...)` guards; Screen Time calls will be no-ops in that case.
- For the full experience, add **Family Controls** + **App Groups** to the app and extension targets.
- Shield UI & Device Activity extensions cannot perform network calls; use `.defer` and let the **main app** handle networking and remove/reapply shields.

Happy building! 🎉
