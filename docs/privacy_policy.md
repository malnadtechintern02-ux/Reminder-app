# Privacy Policy for Time Bell

**Last Updated**: September 2026

Time Bell ("we", "our", or "the App") is developed and provided as a privacy-first productivity and reminder application designed to help you organize your daily tasks, establish routines, and stay on schedule.

We respect your privacy and are committed to protecting it. This Privacy Policy explains how information is handled when you use the Time Bell mobile application.

---

## 1. Information We Collect and Store

Time Bell is built with an offline-first architecture. All task and schedule information created within the app is stored locally on your device in an SQLite database:

- **Reminders & Tasks**: Title, description, schedule date/time, end date/time, recurrence rules, priority level, and completion status.
- **Categories & Tags**: Custom category names, icons, and color assignments.
- **App Preferences**: Theme preferences (Light/Dark/System), custom accent color choices, default snooze interval, focus timer settings, and sound/vibration options.

We do **not** collect your name, email address, phone number, contacts, financial information, or device location.

---

## 2. How Your Information Is Used

Information processed by Time Bell is used strictly to deliver the app's core functions:
- To display, organize, and filter your schedule and reminder lists.
- To schedule exact local alarm notifications and warnings on your device.
- To preserve your display and alert preferences between sessions.
- To allow you to export your data to a JSON backup on demand.

---

## 3. Data Storage & Security

- **Local Storage**: All your personal task and reminder data resides locally on your device.
- **No Mandatory Cloud Sync**: We do not upload your reminders to any cloud servers or third-party databases.
- **Self-Hosted API Sync (Optional)**: If you explicitly configure a custom self-hosted server URL in the app's settings, the app communicates only with the server endpoint you provide. By default, no remote synchronization is performed.
- **Device Security**: Because data is stored on your device, its security corresponds to your device's security configuration (passcode, biometric lock, operating system updates).

---

## 4. Device Permissions Used

Time Bell requests only the minimal device permissions required for its functionality:

| Permission | Purpose |
| :--- | :--- |
| `POST_NOTIFICATIONS` | To post alert notifications when reminders and Pomodoro timers trigger (Android 13+). |
| `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` | To ensure reminder alarms trigger at the exact scheduled second, even when the device is idle or in doze mode. |
| `VIBRATE` | To vibrate the device during reminder alarms when vibration is enabled by the user. |
| `RECEIVE_BOOT_COMPLETED` | To restore and reschedule active reminder alarms after your device is restarted. |
| `USE_FULL_SCREEN_INTENT` | To present the alarm alert display over the lock screen when a critical reminder fires. |
| `INTERNET` | Used solely for opening external links (such as the Google Play Store rating page) and for optional user-configured private server sync. |

The app does **not** request access to your camera, microphone, precise location, contacts, or photo library.

---

## 5. Third-Party Services & Analytics

Time Bell does **not** integrate third-party tracking, advertising, analytics SDKs, or Firebase services. We do not sell, rent, monetize, or transmit your personal data to any third-party marketing or data brokerage platforms.

---

## 6. Children's Privacy

Time Bell does not knowingly collect personally identifiable information from children under the age of 13. Because all data is retained strictly on the user's device, the app is safe for users of all ages.

---

## 7. Changes to This Privacy Policy

We may update our Privacy Policy periodically. Any updates will be posted directly within the application and reflected in the "Last Updated" date above. Continued use of the application signifies acceptance of any updated terms.

---

## 8. Contact Us

If you have questions, feedback, or privacy inquiries regarding Time Bell, please reach out via:
- **Project Repository**: Time Bell App Project
- **Support Inquiries**: Available through the project's issue tracker or developer contact channel.
