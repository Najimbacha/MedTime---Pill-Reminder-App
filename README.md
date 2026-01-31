# MedTime - Smart Pill Reminder & Medication Tracker

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/sqlite-%2307405e.svg?style=for-the-badge&logo=sqlite&logoColor=white)
![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios%20-brightgreen.svg?style=for-the-badge)

MedTime is a premium, privacy-focused medication management application built with Flutter. It helps users stay on track with their health through smart reminders, adherence tracking, and safety features—all while keeping data 100% private and offline-first.

---

## ✨ Key Features

### 🛡️ Privacy First
- **Offline-First Architecture**: Your medical data stays on your device.
- **Local Storage**: Uses SQLite for secure, local data persistence.
- **No Mandatory Cloud**: Full functionality without requiring an account.

### ⏰ Smart Reminders
- **Custom Schedules**: Support for daily, weekly, or specific interval dosing.
- **Robust Snooze System**: Persistent snooze that survives app restarts with custom intervals.
- **Critical Notifications**: Alarms that ensure you never miss a life-critical dose.

### 💊 Medication Management
- **3D Visualization**: Beautiful 3D medicine icons for easy pill identification.
- **Drug Interaction Checker**: Offline database to warn about potentially dangerous drug combinations.
- **Inventory Tracking**: Low-stock alerts to remind you when to refill.

### 📈 Adherence & Gamification
- **Smart Streaks**: Track consecutive perfect days to stay motivated.
- **History & Reports**: Detailed logs of taken, skipped, and snoozed doses.
- **Achievements**: Unlock rewards as you build healthy habits.

### 👥 Caregiver Support
- **Family Sync**: Securely share adherence reports with family or doctors.
- **Remote Monitoring**: Caregivers can receive alerts if a loved one misses a dose.

---

## 🛠️ Technical Stack

- **Framework**: [Flutter](https://flutter.dev)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Database**: [Sqflite](https://pub.dev/packages/sqflite) (SQLite)
- **Notifications**: [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- **Animations**: [Lottie](https://pub.dev/packages/lottie) & [Confetti](https://pub.dev/packages/confetti)
- **Architecture**: Clean, modular structure for scalability.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (Latest Stable)
- Android Studio / VS Code
- Android / iOS Emulator or Physical Device

### Installation
1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/MedTime---Pill-Reminder-App.git
   ```
2. **Navigate to the project directory**:
   ```bash
   cd MedTime---Pill-Reminder-App
   ```
3. **Install dependencies**:
   ```bash
   flutter pub get
   ```
4. **Run the app**:
   ```bash
   flutter run
   ```

---

## 🔒 Security & Data
MedTime takes security seriously. All medication records, schedules, and personal logs are stored in a local SQLite database. 
- **Backups**: Encrypted JSON export/import functionality available in settings.
- **Permissions**: Only requests necessary permissions (Notifications, Alarms).

---

## 🤝 Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

---

Developed with ❤️ by the MedTime Team.
