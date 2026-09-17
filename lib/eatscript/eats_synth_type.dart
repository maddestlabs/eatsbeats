/// High-performance DSP engine dispatch types for Eatscript instruments, drums, and FX.
enum EatSynthType {
  gmDrumKit,
  snesDrumKit,
  sidDrumKit,
  physicalModel,
  proceduralKick,
  acid303,
  proceduralSnare,
  proceduralHiHat,
  fmSynth,
  snesDsp,
  ym2612,
  polySynth,
  defaultSynth,
  userScript;

  bool get isDrumKit =>
      this == EatSynthType.gmDrumKit ||
      this == EatSynthType.snesDrumKit ||
      this == EatSynthType.sidDrumKit;
}

/// High-performance DSP effect types for zero-allocation per-sample audio processing.
enum EatFxType {
  stereoDelay,
  stereoChorus,
  snesDownsample,
  bitcrush,
  tubeDistortion,
  lowpass,
  fallback,
}

/// Procedural automation script generator types for cached lane evaluation.
enum AutomationScriptType {
  lfo,
  ramp,
  adsr,
  breakpoint,
}
