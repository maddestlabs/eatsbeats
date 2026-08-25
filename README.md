# Eatsbeats
Mobile-first and web-first, totally unprofessional digital audio workstation (DAW) built around a core of Lua scripting with a multimedia focused API. Made with Flutter (using wajuce for native Web Audio) and Lua, relying on WebAudio API.

---

## See it live

▶︎ [https://eatsbeats.app/](https://eatsbeats.app/)

---

## Features

- Web-first: Built for easy access on the web
- Made with Flutter (using wajuce for native Web Audio): Easy portability for native mobile and desktop
- Lua scripting: Everything is Lua scripts, built on a WebAudio based API
- Rebirth template: 2 TB-303s, an TR-808, and a TR-909

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x or later)

### Running Locally
```bash
# Clone the repository
git clone https://github.com/maddestlabs/eatsbeats.git
cd eatsbeats

# Fetch dependencies
flutter pub get

# Run Web app locally
flutter run -d chrome
```

### Building Web Release
```bash
flutter build web --release --base-href "/" --pwa-strategy=none
```

---

## 📄 License & Credits
- App codebase licensed under MIT License.
- Bundled default SoundFont: [Super Small Font](https://github.com/nitro-shoe/super-small-font) by nitro-shoe, used under [Creative Commons Attribution 4.0 (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
