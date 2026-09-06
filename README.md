# Eatsbeats
Mobile-first and web-first digital audio workstation (DAW) built with Flutter and powered by **Eatscript**—a pure-Dart, Pythonic audio scripting engine and DSP synthesizer. Utilizes `wajuce` for native Web Audio execution and hardware-accelerated playback.

---

## See it live

▶︎ [https://eatsbeats.app/](https://eatsbeats.app/)

---

## Features

- **Pure-Dart DSP & Eatscript**: 100% VM-less, pure-Dart audio synthesis and Pythonic scripting DSL.
- **Native & Web Portability**: Built with Flutter and `wajuce` (native Web Audio backend) for Windows, macOS, Linux, Android, iOS, and Web.
- **Interactive Music Tracker & Piano Roll**: Real-time sequencing synced to live Eatscript clip automation and MIDI FX pipelines.
- **Dynamic GUI Designer**: Create and customize instrument interfaces with knobs, sliders, XY pads, and ADSR envelopes.
- **Classic Emulations & Rebirth Template**: Built-in procedural 303 acid basslines with slide/accent, 808/909 drum machines, C64 SID, Yamaha FM/OPL3, and SNES DSP chipsets.
- **Physical Modeling & SoundFonts**: Commuted waveguide piano physical models, Karplus-Strong string synthesis, and integrated General MIDI SoundFont support.

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
