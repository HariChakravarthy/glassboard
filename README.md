# 🪟 Glassboard

> **A digital handshake management platform for organizations** — ensuring transparent, verified, tamper-proof delivery accountability between teams.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Blaze-FFCA28?logo=firebase)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 📱 What is Glassboard?

Glassboard is a Flutter mobile application that solves **cross-team delivery accountability** in organizations. When one team finishes work and passes it to another, Glassboard creates a transparent, verified, cryptographically-logged record of that handoff — called a **Handshake**.

Think of it as: **GitHub PRs + Jira + delivery proof**, in a mobile-first package.

---

## ✨ Key Features

### 🔐 Authentication
- Email/Password login and registration
- Google Sign-In (one-tap)
- Role-based access control (org_admin / module_lead / member)

### 📊 Dashboard
- Real-time module stats (total, in-progress, complete)
- **Dependency Graph** — visual pipeline showing module dependency chain with topological layout
- Quick Actions for admins (Users, Files, Audit, Inbox)
- Live module cards with progress bars

### 🧩 Module Management
- Create modules with name, description, status, and dependencies
- Track progress (0–100%) with visual indicators
- View module dependency chain
- Admin-only module creation

### ✅ Task / Checklist System
- Per-module task lists with priority levels (HIGH / MEDIUM / LOW)
- Assign tasks to team members
- Set due dates
- **Handshake Gate**: all tasks must be complete before a handshake can be sent

### 🤝 Handshake System (Core Feature)
- Initiate a digital handoff from one module to another
- Attach a delivery note (text) + proof file (image/PDF/document)
- Receiving module lead gets real-time FCM push notification
- Accept or Reject with mandatory rejection reason
- Full handshake history per module

### 📁 File Management
- Upload files scoped to one or more modules
- Version tracking (v1, v2...)
- **In-app image preview** with pinch-to-zoom
- PDF/Document preview with external open option
- Admin sees all files; members see only their module's files

### 🔔 Push Notifications (FCM)
- Real-time push via Firebase Cloud Functions
- Notification types: handshake received/accepted/rejected, task assigned, file modified
- Overdue handshake escalation to org admins (hourly)
- Unread badge on notification tab

### 🛡️ Admin Panel
- **User Management**: change roles, assign modules in real-time
- **Audit Log**: immutable chronological record of all actions
- **CSV Export**: export audit log via native share sheet

### 🌐 Offline Detection
- Animated connectivity banner appears when internet is lost
- Auto-dismisses on reconnection

---

## 🏗️ Architecture

```
lib/
├── core/
│   ├── constants/          # App-wide constants
│   ├── providers/          # Riverpod providers
│   ├── router/             # GoRouter with ShellRoute (bottom nav)
│   └── theme/              # Dark theme, typography, colors
├── data/
│   ├── models/             # UserModel, ModuleModel, HandshakeModel, etc.
│   └── repositories/       # Firebase data layer (Auth, Module, Handshake, File, Audit, Admin)
├── features/
│   ├── admin/              # Admin user management screen
│   ├── audit/              # Audit log with CSV export
│   ├── auth/               # Login, Register, Onboarding, Profile
│   ├── dashboard/          # Dashboard + Dependency Graph
│   ├── files/              # File list, upload, preview
│   ├── handshake/          # Inbox, Initiate, Detail screens
│   ├── modules/            # Module detail, Create module
│   ├── notifications/      # Notification list screen
│   └── tasks/              # Task checklist screen
├── shared/
│   └── widgets/            # GlassCard, GlassAppBar, MainShell, OfflineBanner, etc.
└── main.dart
```

**State Management**: Riverpod (StreamProvider + AsyncNotifier)  
**Navigation**: GoRouter with ShellRoute (persistent bottom nav)  
**Backend**: Firebase (Firestore + Storage + Auth + FCM + Cloud Functions)

---

## 🚀 Getting Started

### Prerequisites
- Flutter 3.x
- Firebase CLI (`npm install -g firebase-tools`)
- Android Studio / VS Code

### Setup

1. **Clone the repository**
```bash
git clone https://github.com/YOUR_USERNAME/glassboard.git
cd glassboard/glassboard_app
```

2. **Configure Firebase**
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Enable: Firestore, Storage, Authentication (Email + Google), Cloud Messaging
   - Download `google-services.json` → place in `android/app/`
   - Run: `flutterfire configure`

3. **Install dependencies**
```bash
flutter pub get
```

4. **Deploy Firestore rules & indexes**
```bash
firebase deploy --only firestore
firebase deploy --only storage
```

5. **Deploy Cloud Functions**
```bash
cd functions && npm install
firebase deploy --only functions
```

6. **Run the app**
```bash
flutter run
```

7. **Set first admin** — In Firestore → `users` collection → your UID doc → set `role: "org_admin"`

---

## 🔥 Firebase Cloud Functions

Five triggers automatically fire on Firestore events:

| Function | Trigger | Notifies |
|----------|---------|---------|
| `onHandshakeCreated` | New handshake document | Module leads of receiving module |
| `onHandshakeUpdated` | Status change (accept/reject) | Members of sending module |
| `onTaskCreated` | New task with assignee | The assigned user |
| `onFileUpdated` | File version update | All users in scoped modules |
| `escalateOverdueHandshakes` | Every 60 minutes | Org admins (for 24h+ pending) |

---

## 📸 Screens

| Dashboard | Module Detail | Handshake Inbox |
|-----------|---------------|-----------------|
| Stats, graph, modules | Tasks, progress, handshake | Pending handshakes, accept/reject |

| Files | Audit Log | Admin Users |
|-------|-----------|-------------|
| Upload, preview | Immutable log, CSV export | Role & module assignment |

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|-----------|
| Framework | Flutter 3.x |
| Language | Dart 3.x |
| State Mgmt | Riverpod 2.x |
| Navigation | GoRouter 14.x |
| Backend | Firebase (Firestore, Storage, Auth) |
| Push | Firebase Cloud Messaging (FCM) |
| Functions | Firebase Cloud Functions (Node.js) |
| UI | Custom dark theme, flutter_animate, fl_chart |
| Fonts | Google Fonts (Inter, Space Mono) |

---

## 📋 Environment Variables / Secrets

The following files are **not committed** and must be set up manually:
- `android/app/google-services.json` — Firebase Android config
- `ios/Runner/GoogleService-Info.plist` — Firebase iOS config  
- `android/key.properties` — Release signing config

---

## 👥 Team

Built by **Nomula Hari Chakravarthy**

---

## 📄 License

This project is licensed under the MIT License.
