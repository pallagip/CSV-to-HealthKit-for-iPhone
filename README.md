# CSV to HealthKit for iPhone

A high-performance, native iOS application built with **SwiftUI** and **HealthKit** to import, parse, and synchronize historical Blood Glucose (CGM / Sensor Glucose) records from CSV files directly into Apple Health.

[![Platform: iOS 17+](https://img.shields.io/badge/Platform-iOS%2017%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift 5.10 / Swift 6 Ready](https://img.shields.io/badge/Swift-5.10%20%2F%206-orange.svg)](https://swift.org)
[![Xcode 16+](https://img.shields.io/badge/Xcode-16%2B-black.svg)](https://developer.apple.com/xcode/)
[![Framework: HealthKit](https://img.shields.io/badge/HealthKit-Enabled-red.svg)](https://developer.apple.com/documentation/healthkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Features

- ⚡ **Ultra-Fast Streaming Parser**:
  - Parses **100,000+ glucose entries in under 1.6 seconds** off the main actor without UI stutter.
  - Zero memory bloat through line enumeration and fast integer-based timestamp parsing.
- 🩺 **Native HealthKit Integration**:
  - Automatically calculates Blood Glucose units using accurate molar mass (`mmol/L` with `HKUnitMolarMassBloodGlucose`).
  - Displays dual units (`mmol/L` and `mg/dL`) in real-time.
- 🛡️ **Built-in Deduplication**:
  - Sets deterministic `HKMetadataKeySyncIdentifier` and `HKMetadataKeySyncVersion` metadata to ensure tapping sync repeatedly never generates duplicate HealthKit records.
- 📱 **Native File Picker (`.fileImporter`)**:
  - Securely accesses CSV files from iPhone Local Storage, iCloud Drive, or external drives with proper security-scoped resource lifecycles.
- 🔄 **Real-Time Batch Syncing**:
  - Saves samples in chunks of 1,000 records with a live progress bar and status indicator.
- 🔐 **Permission Management**:
  - Dedicated HealthKit authorization cards and status indicators.
  - Direct deep links to iPhone Settings if permissions are turned off.
- 📊 **Dual Tab Preview**:
  - Inspect loaded CSV rows and recent Apple Health entries side-by-side.

---

## Supported CSV Formats

The parser automatically detects delimiters (`;` or `,`) and column configurations:

### Combined / Standard Format
```csv
Date;Time;Blood Glucose (mmol/L);Reading Type;Event Marker;Source File
2025-07-01;00:02:20;6,70;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
2025-07-01;00:07:20;6,60;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
```

### Medtronic CareLink / Guardian Export Format
- Semicolon or comma-separated exports.
- Comma `,` or dot `.` decimal formatting (e.g., `6,70` or `6.70`).
- Date timestamps in `YYYY-MM-DD`, `YYYY/MM/DD`, or `YYYY.MM.DD`.

---

## Project Structure

```
.
├── MyApp/
│   ├── MyApp.swift                 # App entry point
│   ├── ContentView.swift           # Main SwiftUI dashboard & file picker
│   ├── HealthKitManager.swift      # HealthKit authorization & batch sync engine
│   ├── BloodGlucoseCSVParser.swift # High-performance streaming CSV parser
│   ├── BloodGlucoseModels.swift    # Data models (BloodGlucoseReading, SyncStatus)
│   ├── MyApp.entitlements          # HealthKit entitlements
│   ├── sample_blood_glucose.csv    # Bundled reference dataset (50 rows)
│   └── Assets.xcassets             # App icons & color assets
├── Untitled Project.xcodeproj      # Xcode Project configuration
└── README.md
```

---

## Getting Started

### Prerequisites

- Mac with **macOS Sonoma** (14.0+) or **Sequoia** (15.0+).
- **Xcode 16.0+**.
- Physical iPhone (or iOS Simulator) running **iOS 17.0+**.

### Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/pallagip/CSV-to-HealthKit-for-iPhone.git
   cd CSV-to-HealthKit-for-iPhone
   ```

2. **Open the project in Xcode:**
   ```bash
   open "Untitled Project.xcodeproj"
   ```

3. **Configure Signing & Capabilities:**
   - In Xcode, select the **MyApp** target.
   - Under the **Signing & Capabilities** tab:
     - Select your Apple Developer Team.
     - Ensure the **HealthKit** capability is enabled.

4. **Build and Run:**
   - Select your target device (e.g. `iPhone 17` simulator or connected iPhone).
   - Press **Cmd + R** to run.

---

## Usage

1. Launch the app on your iPhone.
2. Tap **"Authorize"** to grant read/write access to Blood Glucose data in Apple Health.
3. Tap **"Choose CSV File from iPhone..."** and select your Blood Glucose CSV.
4. Watch the progress bar as your records are synchronized into Apple Health.
5. Open Apple's **Health app** -> **Browse** -> **Blood Glucose** to see your data graphed!

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
