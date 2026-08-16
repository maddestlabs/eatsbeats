# Eatsbits
Mobile-first and web-first, totally unprofessional digital everything workstation (DEW) built around a core of Lua scripting with a multimedia focused API. Made with Flutter and Lua, relying on WebAudio API for audio features.

---

## See it live

▶︎ [https://eatsbits.app/](https://eatsbits.app/)

---

## Features

- Web-first: Built for easy access on the web
- Made with Flutter: Easy portability for native mobile and desktop
- Lua scripting: Everything is Lua scripts, built on a WebAudio based API

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x or later)

### Running Locally
```bash
# Clone the repository
git clone https://github.com/maddestlabs/eatsbits.git
cd eatsbits

# Fetch dependencies
flutter pub get

# Run Web app locally
flutter run -d chrome
```

### Building Web Release
```bash
flutter build web --release --base-href "/" --pwa-strategy=none
```

## GitHub Pages Build Stability

GitHub Pages deploys this app with Flutter web, and the Pages runner is less forgiving than local hot reload. The most recent breakages came from reintroducing `google_fonts`, which currently fails `dart2js` under the Flutter version used in CI.

Avoid these regressions with these rules:

- Prefer bundled fonts or generic `sans-serif` and `monospace` families for web builds instead of runtime font packages.
- Keep the Pages workflow on a pinned Flutter SDK version so upstream `stable` changes do not silently change the compiler/toolchain.
- Before pushing UI, dependency, or web bootstrap changes, run `flutter pub get`, `flutter analyze`, and `flutter build web --release --base-href "/"` locally.
- Treat `pubspec.yaml`, `pubspec.lock`, and `.github/workflows/deploy.yml` as one deployment surface. If one changes, verify the web release build before merging.
- If remote fonts are required later, bundle them as project assets and declare them in Flutter rather than depending on `google_fonts` for the Pages build path.

---

## 📄 License & Credits
- App codebase licensed under MIT License.
- Bundled default SoundFont: [Super Small Font](https://github.com/nitro-shoe/super-small-font) by nitro-shoe, used under [Creative Commons Attribution 4.0 (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
