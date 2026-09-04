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
- Music Tracker and Piano roll editor synced to Lua scripting.
- AI supported workflow: Everything is Lua scripts, AI knows Lua
- Rebirth template: 2 303s, an 808, and a 909
- Full General MIDI coverage in bundled instruments including physical models and synthesizers
- Built-in synths for C64 SID, OPL3, SNES and more.

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
- **Commuted Waveguide Piano Physical Models**: Based on research by Balázs Bank, Julien Bensa, Julius O. Smith, and Scott Van Duyne (CCRMA, Stanford University). DSP topology and empirical 88-key breakpoint tables derived from Romain Michon's Faust/STK implementation (`physmodels.lib`, GRAME / Stanford CCRMA) and David Braun's ([DBraun](https://gist.github.com/DBraun/3d1c735ffb414f7ce371b28a20559e30)) physical modeling adaptation (STK-4.3 / MIT License).
- Bundled default SoundFont: [Super Small Font](https://github.com/nitro-shoe/super-small-font) by nitro-shoe, used under [Creative Commons Attribution 4.0 (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
