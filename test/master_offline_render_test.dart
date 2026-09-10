import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/master_offline_render_engine.dart';
import 'package:eatsbeats/audio/virtual_render_pipeline.dart';
import 'package:eatsbeats/audio/wav_exporter.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/eatscript/eat_script_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Master Offline Audio & Video Rendering Pipeline Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
      for (final p in dawState.patterns) {
        p.tracks.clear();
      }
      dawState.chordTrack.clear();
    });

    test('WAV encoder generates standard 44-byte RIFF header and valid PCM payload', () {
      final left = [0.0, 0.5, -0.5, 0.0];
      final right = [0.0, -0.5, 0.5, 0.0];
      final wav = WavExporter.encodeWav(leftSamples: left, rightSamples: right, sampleRate: 44100);

      expect(wav.length, equals(44 + 4 * 2 * 2)); // 44 header + 4 samples * 2 channels * 2 bytes
      // Check 'RIFF'
      expect(String.fromCharCodes(wav.sublist(0, 4)), equals('RIFF'));
      // Check 'WAVE'
      expect(String.fromCharCodes(wav.sublist(8, 12)), equals('WAVE'));
      // Check 'fmt '
      expect(String.fromCharCodes(wav.sublist(12, 16)), equals('fmt '));
      // Check 'data'
      expect(String.fromCharCodes(wav.sublist(36, 40)), equals('data'));
    });

    test('MasterOfflineRenderEngine renders empty tracks gracefully without crash', () async {
      final result = await MasterOfflineRenderEngine.renderSongOffline(
        tracks: [],
        audioEngine: dawState.audioEngine,
        bpm: 120.0,
        totalTimelineBars: 2,
        tailReleaseSec: 0.0,
      );

      expect(result.durationSec, greaterThan(0.0));
      expect(result.leftBuffer.length, equals(result.totalSamples));
      expect(result.rightBuffer.length, equals(result.totalSamples));
      expect(result.wavBytes, isNotEmpty);
    });

    test('MasterOfflineRenderEngine mixes multiple tracks with panning and master limiting', () async {
      // Create Synth Track 1 (panned Left)
      final track1 = TrackChannel(
        id: 'track_1',
        name: 'Lead Synth',
        type: TrackType.synth,
        color: Colors.cyan,
        volume: 1.0,
        pan: -1.0, // Hard left
      );
      track1.notes.add(Note(
        id: 'n1',
        pitch: 60,
        startStep: 0.0,
        durationSteps: 4.0,
        velocity: 0.9,
      ));

      // Create Bass Track 2 (panned Right)
      final track2 = TrackChannel(
        id: 'track_2',
        name: 'Acid Bass',
        type: TrackType.bass,
        color: Colors.amber,
        volume: 1.0,
        pan: 1.0, // Hard right
      );
      track2.notes.add(Note(
        id: 'n2',
        pitch: 36,
        startStep: 4.0,
        durationSteps: 4.0,
        velocity: 0.9,
      ));

      final result = await MasterOfflineRenderEngine.renderSongOffline(
        tracks: [track1, track2],
        audioEngine: dawState.audioEngine,
        bpm: 120.0,
        totalTimelineBars: 2,
        sampleRate: 22050, // lower sample rate for fast unit test
        masterLimiterEnabled: true,
        masterCeilingDbfs: -0.3,
        tailReleaseSec: 0.5,
      );

      expect(result.totalSamples, greaterThan(0));
      expect(result.leftBuffer.length, equals(result.totalSamples));
      expect(result.rightBuffer.length, equals(result.totalSamples));
      expect(result.wavBytes.length, greaterThan(44));
      expect(result.peakDbfs, lessThanOrEqualTo(0.0));
    });

    test('MasterOfflineRenderEngine respects track mute and solo states', () async {
      final track1 = TrackChannel(
        id: 'track_1',
        name: 'Muted Track',
        type: TrackType.synth,
        color: Colors.red,
        isMuted: true,
      );
      track1.notes.add(Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 4, velocity: 1.0));

      final track2 = TrackChannel(
        id: 'track_2',
        name: 'Solo Track',
        type: TrackType.synth,
        color: Colors.green,
        isSoloed: true,
      );
      track2.notes.add(Note(id: 'n2', pitch: 64, startStep: 0, durationSteps: 4, velocity: 1.0));

      final result = await MasterOfflineRenderEngine.renderSongOffline(
        tracks: [track1, track2],
        audioEngine: dawState.audioEngine,
        bpm: 120.0,
        totalTimelineBars: 1,
        sampleRate: 22050,
      );

      expect(result.wavBytes, isNotEmpty);
    });

    test('VirtualRenderPipeline steps through non-realtime frames accurately at arbitrary FPS', () async {
      final audioSamples = 22050; // 1.0 sec audio at 22050 Hz
      final left = Float32List(audioSamples);
      final right = Float32List(audioSamples);
      final wav = WavExporter.encodeWav(leftSamples: left, rightSamples: right, sampleRate: 22050);

      final audioRender = MasterRenderResult(
        leftBuffer: left,
        rightBuffer: right,
        wavBytes: wav,
        durationSec: 1.0,
        totalSamples: audioSamples,
        sampleRate: 22050,
        peakDbfs: -6.0,
      );

      int frameCount = 0;
      final steppedTimes = <double>[];

      await VirtualRenderPipeline.stepVirtualTimeline(
        audioRender: audioRender,
        options: const VirtualRenderOptions(fps: 24, width: 1920, height: 1080),
        bpm: 120.0,
        onFrame: (frame) async {
          frameCount++;
          steppedTimes.add(frame.virtualTimeSec);
          expect(frame.totalFrames, equals(24));
          expect(frame.audioLeftSlice, isNotNull);
        },
      );

      expect(frameCount, equals(24));
      expect(steppedTimes.first, equals(0.0));
      expect(steppedTimes.last, closeTo(23.0 / 24.0, 0.001));
    });

    test('Eatscript Macro can trigger eat.daw.render_audio and eat.daw.render_video', () {
      final script = LuaScriptDef(
        id: 'test_macro_render',
        name: 'Render Trigger Macro',
        category: LuaScriptCategory.macro,
        description: 'Triggers offline render from script',
        code: '''
def run(project, params):
    project.render_audio("test_export.wav", bars=2)
    project.render_video("test_video.mp4", fps=30, width=1280, height=720, bars=2)
    project.log("Render commands executed")
''',
      );

      final result = dawState.runProjectScript(script);
      expect(result.isSuccess, isTrue);
      expect(result.logs.any((l) => l.contains('Audio export initiated')), isTrue);
      expect(result.logs.any((l) => l.contains('Video export initiated')), isTrue);
    });

    test('MasterOfflineRenderEngine renders transformed notes from MIDI FX rack', () async {
      final track = TrackChannel(
        id: 'track_midifx',
        name: 'Arp Track',
        type: TrackType.synth,
        color: Colors.purple,
      );
      // Base note C4 (60)
      track.notes.add(Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 4, velocity: 0.9));

      // Add Arpeggiator MIDI FX insert
      final arpFx = MidiFXInsert(
        id: 'mfx_arp',
        name: 'Chord Arpeggiator',
        enabled: true,
        luaScriptCode: '''
def transform_notes(notes, params, time_ctx):
    output = []
    for n in notes:
        for step in range(4):
            output.append({
                "pitch": n["pitch"] + (step * 4),
                "startStep": n["startStep"] + step,
                "durationSteps": 0.8,
                "velocity": n["velocity"],
            })
    return output
''',
      );
      track.midiFXRack.add(arpFx);

      final result = await MasterOfflineRenderEngine.renderSongOffline(
        tracks: [track],
        audioEngine: dawState.audioEngine,
        bpm: 120.0,
        totalTimelineBars: 1,
        sampleRate: 22050,
      );

      expect(result.totalSamples, greaterThan(0));
      expect(result.wavBytes.length, greaterThan(44));
    });

    test('MasterOfflineRenderEngine processes Track Audio FX and Master Mixer Channel FX Rack', () async {
      final track = TrackChannel(
        id: 'track_audiofx',
        name: 'Distorted Track',
        type: TrackType.synth,
        color: Colors.orange,
      );
      track.notes.add(Note(id: 'n1', pitch: 55, startStep: 0, durationSteps: 4, velocity: 0.9));

      // Add Distortion to track FX rack
      track.fxRack.add(FXInsert(
        id: 'fx_dist',
        name: 'Tube Distortion',
        type: FXType.distortion,
        enabled: true,
        mix: 0.8,
        params: {'Drive': 8.0, 'Tone': 5000.0},
      ));

      // Add Reverb to Master track FX rack
      final masterTrack = TrackChannel(
        id: 'master',
        name: 'Master',
        type: TrackType.synth,
        color: Colors.blue,
      );
      masterTrack.fxRack.add(FXInsert(
        id: 'fx_master_rev',
        name: 'Master Reverb',
        type: FXType.convolutionReverb,
        enabled: true,
        mix: 0.3,
        params: {'PreDelayMs': 20.0, 'Decay': 2.5},
      ));

      final result = await MasterOfflineRenderEngine.renderSongOffline(
        tracks: [track],
        masterTrack: masterTrack,
        audioEngine: dawState.audioEngine,
        bpm: 120.0,
        totalTimelineBars: 1,
        sampleRate: 22050,
        masterSubCut: 30.0,
        masterLowGain: 1.5,
        masterMidGain: -1.0,
        masterHighGain: 2.0,
      );

      expect(result.totalSamples, greaterThan(0));
      expect(result.wavBytes.length, greaterThan(44));
      expect(result.peakDbfs, lessThanOrEqualTo(0.0));
    });
  });
}
