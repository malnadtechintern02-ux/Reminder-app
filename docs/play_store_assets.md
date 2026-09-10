# Google Play Store Asset Specifications & Guidelines

This document outlines all graphic assets, screenshot specifications, and signing requirements for releasing **Time Bell** on Google Play Console.

---

## 1. App Icon (Launcher & Store)

| Property | Requirement |
| :--- | :--- |
| **Format** | 32-bit PNG (with alpha) |
| **Dimensions** | 512 × 512 pixels |
| **Maximum File Size** | 1,024 KB |
| **Color Space** | sRGB |
| **Design** | Clean brand mark matching `assets/images/logo.png` on `#0F172A` background |
| **Source Asset** | Located at `Mobileapp/assets/images/logo.png` |

> **Action Item**: Export `Mobileapp/assets/images/logo.png` at exactly 512 × 512 px for the Play Console "App icon" upload field.

---

## 2. Feature Graphic (Play Store Banner)

| Property | Requirement |
| :--- | :--- |
| **Format** | JPEG or 24-bit PNG (no alpha) |
| **Dimensions** | 1024 × 500 pixels |
| **Aspect Ratio** | ~ 2.05 : 1 |
| **Maximum File Size** | 15 MB |
| **Safe Zone** | Keep critical text/logo within center 800 × 400 px (edges may be cropped across devices) |
| **Content Recommendations** | - App title "Time Bell" with sleek typography<br>- Subtitle "Never Miss a Moment"<br>- Clean visual representation of alarm bell / task card on deep indigo/navy background (`#0F172A` to `#1E1B4B`)<br>- Do not include device frames or promotional badge copy ("#1 app", "Best app") |

> **TODO / Release Requirement**: Before publishing the Play Store listing, generate or provide a 1024 × 500 px graphic according to the above specifications.

---

## 3. Mobile Screenshots (Required for Play Store Listing)

Google Play requires a minimum of 2 screenshots, but 4 to 8 high-resolution screenshots are recommended.

| Property | Requirement |
| :--- | :--- |
| **Format** | 24-bit PNG or JPEG |
| **Recommended Resolution** | 1080 × 1920 px (Portrait 9:16) or 1440 × 3120 px |
| **Minimum Dimension** | 320 px (minimum aspect ratio: 16:9 or 9:16) |
| **Maximum Dimension** | 3840 px |
| **Clean Capture** | Ensure `debugShowCheckedModeBanner: false` (already configured in `lib/app/app.dart`). Capture with representative sample data (no "Test 123" or placeholder strings). |

### Recommended Screens to Capture:

1. **Schedule / Daily Timeline (`SchedulePage`)**
   - *Route*: `/schedule`
   - *Caption*: "Track Your Daily Timeline & Progress at a Glance"
   - Shows active tasks, today's completion stats, and chronologically ordered reminders.

2. **Reminders Hub (`RemindersPage`)**
   - *Route*: `/reminders`
   - *Caption*: "Categorized & Priority-Driven Task Management"
   - Shows active tab, category badges (Work, Personal, Study), and priority tags.

3. **Add & Edit Reminder (`ReminderFormScreen`)**
   - *Route*: `/reminders/create`
   - *Caption*: "Customizable Alarms, Ringtones & Repeating Schedules"
   - Shows date/time picker, sound selection, snooze configuration, and recurrence selector.

4. **Monthly Calendar (`CalendarPage`)**
   - *Route*: `/calendar`
   - *Caption*: "Interactive Calendar with Visual Schedule Markers"
   - Shows month grid with event dots and bottom schedule preview.

5. **Pomodoro Focus Timer (`PomodoroPage`)**
   - *Route*: `/pomodoro`
   - *Caption*: "Integrated Focus Timer for Deep Work & Break Cycles"
   - Shows circular focus timer with session count and play/pause controls.

6. **Customization & Dark Mode (`SettingsPage`)**
   - *Route*: `/settings`
   - *Caption*: "Personalize Themes, Custom Accents & Curated Ringtones"
   - Shows dark/light theme switch, color picker, and offline backup options.

---

## 4. Release Keystore & App Signing

Google Play Console requires apps to be signed. For Google Play App Signing:

1. Generate your production release keystore (keep this file secure):
   ```bash
   keytool -genkey -v -keystore c:/keys/timebell-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias timebell
   ```

2. Create `Mobileapp/android/key.properties` (this file is excluded from git):
   ```properties
   storePassword=<your-keystore-password>
   keyPassword=<your-key-password>
   keyAlias=timebell
   storeFile=c:/keys/timebell-release.jks
   ```

3. Build the production App Bundle:
   ```bash
   flutter build appbundle --release
   ```
   *The Gradle script automatically loads `key.properties` if present, falling back to debug keys for local verification.*
