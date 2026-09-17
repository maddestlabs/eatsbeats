# Eatsbeats
Mobile-first and web-first, highly experimental digital audio workstation (DAW) built with Flutter and powered by **Eatscript**: a Pythonic audio scripting engine and DSP synthesizer.

## Built with:
- Google Antigravity/Gemini for fast AI based development 
- Dart/Flutter for cross-platform GUI
- wajuce for native Web Audio execution

---

## See it live

▶︎ [https://eatsbeats.app/](https://eatsbeats.app/)

---

## Features

- **Native & Web Portability**: Built with Flutter and `wajuce` (native Web Audio backend) for Windows, macOS, Linux, Android, iOS, and Web.
- **Bi-Directional Modular Synthesis Studio (Eurorack / VCV Rack style)**: Real-time visual cable patching synchronized 1:1 with Pythonic Eatscript (`def graph():`), compiling directly into zero-allocation native C/Dart `GraphNode` DSP audio trees.
- **Hybrid Music Tracker / Piano Roll / Score / Code editor**: Real-time sequencing synced to live Eatscript clip automation and MIDI FX pipelines.
- **Dynamic GUI Designer**: Create and customize hardware instrument interfaces with knobs, sliders, nixie tubes, oscilloscopes, and ADSR envelopes.
- **Classic Emulations & Rebirth Template**: Built-in procedural 303 acid basslines with slide/accent, 808/909 drum machines, C64 SID, Yamaha FM/OPL3, and SNES DSP chipsets.
- **Physical Modeling & SoundFonts**: Commuted waveguide piano physical models, Karplus-Strong string synthesis, modal resonator banks, and integrated General MIDI SoundFont support.
- **Studio Master Dynamics & Audio FX**: Native zero-latency VCA compressors, brickwall peak limiters, multimode state-variable filters, tape delays, and stereo modulated choruses.

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
