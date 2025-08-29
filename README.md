# BuddyLock

BuddyLock is an iOS app prototype built with SwiftUI, FamilyControls, and ManagedSettings. It helps you **limit screen time** and adds a social accountability layer by letting your friends act as buddies. Buddies can approve unlock requests, compete in challenges, and keep you accountable.

---

## ✨ Features

- **Focus Sessions**  
  - Shield selected apps, categories, and domains.  
  - Warm-up timer to resist impulses before the session starts.  
  - Schedule sessions for later.  
  - Auto-log completed focus minutes into challenges.

- **Buddy System**  
  - Add buddies and manage them from the **Settings (gear icon)**.  
  - Send unlock requests via **Ask Buddy**.  
  - Approve or deny requests via **Approvals**.  
  - Approvals can be for *all apps* or for a **specific app only**.  
  - Temporary exceptions automatically expire and shields re-apply.

- **Challenges**  
  - Create **Head-to-Head** or **Group** challenges.  
  - Track standings by total focus minutes.  
  - Manual logging supported for corrections.  
  - Leaderboards auto-update as focus sessions complete.

- **Settings/Profile**  
  - Manage display name.  
  - Manage buddies.  
  - Future preferences and profile options live here.

---

## 🛠️ Tech Overview

- **SwiftUI** for the main UI  
- **FamilyControls + ManagedSettings** for app/web shielding  
- **UserDefaults** for local persistence of buddies, requests, and challenges  
- **Local prototype only** — no cloud sync yet (CloudKit can be added later)

---

## 🚀 Getting Started

1. Clone this repo.  
2. Open in **Xcode 15+**.  
3. Run on an iOS 16+ device or simulator.  
4. First launch will prompt for **Screen Time (FamilyControls)** authorization.  

---

## 📌 Roadmap

- [ ] CloudKit support for syncing buddies and challenges across devices  
- [ ] Richer challenge stats (streaks, best sessions, win history)  
- [ ] Motivational nudges and reminders  
- [ ] Improved app name resolution for requests  

---

## ⚠️ Disclaimer

This is a **prototype** intended for experimentation. It currently uses **local storage only**, meaning buddies, requests, and challenges exist only on the same device.
