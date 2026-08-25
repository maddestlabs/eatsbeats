import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/track_model.dart';

class ParsedMidiSong {
  final int format;
  final int ppqn;
  final double? bpm;
  final int? timeSignatureNumerator;
  final int? timeSignatureDenominator;
  final List<ParsedMidiTrack> tracks;

  ParsedMidiSong({
    required this.format,
    required this.ppqn,
    this.bpm,
    this.timeSignatureNumerator,
    this.timeSignatureDenominator,
    required this.tracks,
  });

  int get totalBars {
    if (tracks.isEmpty) return 4;
    int maxBar = 4;
    for (final track in tracks) {
      if (track.totalBars > maxBar) {
        maxBar = track.totalBars;
      }
    }
    return maxBar;
  }
}

class ParsedMidiTrack {
  final int trackIndex;
  String name;
  int? channel;
  int? programNumber;
  final List<Note> notes;

  ParsedMidiTrack({
    required this.trackIndex,
    required this.name,
    this.channel,
    this.programNumber,
    required this.notes,
  });

  int get totalBars {
    if (notes.isEmpty) return 4;
    double maxStep = 0.0;
    for (final note in notes) {
      final end = note.startStep + note.durationSteps;
      if (end > maxStep) maxStep = end;
    }
    return math.max(4, (maxStep / 16.0).ceil());
  }
}

class MidiFileParser {
  /// Parses standard MIDI file (.mid / .midi) bytes into a structured `ParsedMidiSong`.
  static ParsedMidiSong? parse(Uint8List bytes) {
    try {
      if (bytes.length < 14) return null;

      final byteData = ByteData.sublistView(bytes);
      int offset = 0;

      // 1. Read 'MThd' header chunk
      final headerTag = utf8.decode(bytes.sublist(offset, offset + 4), allowMalformed: true);
      if (headerTag != 'MThd') {
        debugPrint('MidiFileParser: Invalid MIDI header tag: "$headerTag"');
        return null;
      }
      offset += 4;

      final headerLength = byteData.getUint32(offset);
      offset += 4;

      final format = byteData.getUint16(offset);
      offset += 2;

      final numTracks = byteData.getUint16(offset);
      offset += 2;

      final division = byteData.getUint16(offset);
      offset += 2;

      int ppqn = 480; // default PPQN
      if ((division & 0x8000) == 0) {
        ppqn = division;
      } else {
        final fps = (division >> 8) & 0x7F;
        final ticksPerFrame = division & 0xFF;
        ppqn = fps * ticksPerFrame;
      }
      if (ppqn <= 0) ppqn = 480;

      // Skip any extra header bytes beyond standard 6 bytes
      if (headerLength > 6) {
        offset += (headerLength - 6);
      }

      double? songBpm;
      int? timeSigNum;
      int? timeSigDenom;
      final List<ParsedMidiTrack> parsedTracks = [];

      // 2. Parse Tracks
      for (int t = 0; t < numTracks && offset < bytes.length - 8; t++) {
        final chunkTag = utf8.decode(bytes.sublist(offset, offset + 4), allowMalformed: true);
        offset += 4;

        final chunkLength = byteData.getUint32(offset);
        offset += 4;

        if (chunkTag != 'MTrk') {
          // Skip non-track chunk
          offset += chunkLength;
          continue;
        }

        final trackEnd = math.min(bytes.length, offset + chunkLength);
        final trackNotes = <Note>[];
        String trackName = '';
        int? trackChannel;
        int? trackProgram;

        // Active note map: key is (channel << 8) | pitch -> (startTick, velocity)
        final Map<int, ({int startTick, double velocity})> activeNotes = {};

        int currentTick = 0;
        int runningStatus = 0;

        while (offset < trackEnd) {
          // Read delta time (VLQ)
          final deltaResult = _readVlq(bytes, offset);
          offset = deltaResult.newOffset;
          currentTick += deltaResult.value;

          if (offset >= trackEnd) break;

          int statusByte = bytes[offset];

          if ((statusByte & 0x80) != 0) {
            // New status byte
            statusByte = bytes[offset++];
            if (statusByte < 0xF0) {
              runningStatus = statusByte;
            }
          } else {
            // Running status
            statusByte = runningStatus;
          }

          if (statusByte == 0xFF) {
            // Meta Event
            if (offset >= trackEnd) break;
            final metaType = bytes[offset++];
            final metaLenResult = _readVlq(bytes, offset);
            offset = metaLenResult.newOffset;
            final metaLen = metaLenResult.value;

            if (offset + metaLen > bytes.length) break;

            if (metaType == 0x03) {
              // Track Name
              trackName = utf8.decode(
                bytes.sublist(offset, offset + metaLen),
                allowMalformed: true,
              ).trim();
            } else if (metaType == 0x51 && metaLen == 3) {
              // Set Tempo (microseconds per quarter note)
              final usPerQuarter = (bytes[offset] << 16) | (bytes[offset + 1] << 8) | bytes[offset + 2];
              if (usPerQuarter > 0) {
                final bpm = 60000000.0 / usPerQuarter;
                songBpm ??= bpm.clamp(20.0, 300.0);
              }
            } else if (metaType == 0x58 && metaLen >= 2) {
              // Time Signature
              timeSigNum ??= bytes[offset];
              timeSigDenom ??= math.pow(2, bytes[offset + 1]).toInt();
            } else if (metaType == 0x2F) {
              // End of Track
              offset += metaLen;
              break;
            }

            offset += metaLen;
          } else if (statusByte == 0xF0 || statusByte == 0xF7) {
            // SysEx Event
            final sysexLenResult = _readVlq(bytes, offset);
            offset = sysexLenResult.newOffset + sysexLenResult.value;
          } else {
            // Channel Voice Message
            final eventType = statusByte & 0xF0;
            final channel = statusByte & 0x0F;
            trackChannel ??= channel;

            if (eventType == 0x80) {
              // Note Off
              if (offset + 1 >= trackEnd) break;
              final pitch = bytes[offset++];
              /* final releaseVel = */ bytes[offset++];
              final key = (channel << 8) | pitch;
              final active = activeNotes.remove(key);
              if (active != null) {
                final startStep = (active.startTick / ppqn) * 4.0;
                final durationSteps = math.max(0.25, ((currentTick - active.startTick) / ppqn) * 4.0);
                trackNotes.add(Note(
                  id: 'midi_n_${t}_${pitch}_${active.startTick}',
                  pitch: pitch,
                  startStep: (startStep * 100).round() / 100.0,
                  durationSteps: (durationSteps * 100).round() / 100.0,
                  velocity: active.velocity,
                ));
              }
            } else if (eventType == 0x90) {
              // Note On
              if (offset + 1 >= trackEnd) break;
              final pitch = bytes[offset++];
              final velocityByte = bytes[offset++];
              final key = (channel << 8) | pitch;

              if (velocityByte == 0) {
                // Note On with vel 0 == Note Off
                final active = activeNotes.remove(key);
                if (active != null) {
                  final startStep = (active.startTick / ppqn) * 4.0;
                  final durationSteps = math.max(0.25, ((currentTick - active.startTick) / ppqn) * 4.0);
                  trackNotes.add(Note(
                    id: 'midi_n_${t}_${pitch}_${active.startTick}',
                    pitch: pitch,
                    startStep: (startStep * 100).round() / 100.0,
                    durationSteps: (durationSteps * 100).round() / 100.0,
                    velocity: active.velocity,
                  ));
                }
              } else {
                // If previous note on same key was unclosed, close it
                final prev = activeNotes.remove(key);
                if (prev != null) {
                  final startStep = (prev.startTick / ppqn) * 4.0;
                  final durationSteps = math.max(0.25, ((currentTick - prev.startTick) / ppqn) * 4.0);
                  trackNotes.add(Note(
                    id: 'midi_n_${t}_${pitch}_${prev.startTick}',
                    pitch: pitch,
                    startStep: (startStep * 100).round() / 100.0,
                    durationSteps: (durationSteps * 100).round() / 100.0,
                    velocity: prev.velocity,
                  ));
                }
                activeNotes[key] = (
                  startTick: currentTick,
                  velocity: (velocityByte / 127.0).clamp(0.05, 1.0),
                );
              }
            } else if (eventType == 0xA0) {
              // Polyphonic Aftertouch
              offset += 2;
            } else if (eventType == 0xB0) {
              // Control Change
              offset += 2;
            } else if (eventType == 0xC0) {
              // Program Change
              if (offset < trackEnd) {
                trackProgram = bytes[offset++];
              }
            } else if (eventType == 0xD0) {
              // Channel Aftertouch
              offset += 1;
            } else if (eventType == 0xE0) {
              // Pitch Bend
              offset += 2;
            }
          }
        }

        // Close any lingering notes that didn't receive Note Off
        for (final entry in activeNotes.entries) {
          final pitch = entry.key & 0xFF;
          final active = entry.value;
          final startStep = (active.startTick / ppqn) * 4.0;
          final durationSteps = math.max(0.5, ((currentTick - active.startTick) / ppqn) * 4.0);
          trackNotes.add(Note(
            id: 'midi_n_${t}_${pitch}_${active.startTick}',
            pitch: pitch,
            startStep: (startStep * 100).round() / 100.0,
            durationSteps: (durationSteps * 100).round() / 100.0,
            velocity: active.velocity,
          ));
        }

        // Sort notes chronologically
        trackNotes.sort((a, b) {
          final cmp = a.startStep.compareTo(b.startStep);
          if (cmp != 0) return cmp;
          return a.pitch.compareTo(b.pitch);
        });

        if (trackName.isEmpty) {
          if (trackChannel == 9) {
            trackName = 'Drums';
          } else {
            trackName = 'Track ${t + 1}';
          }
        }

        parsedTracks.add(ParsedMidiTrack(
          trackIndex: t,
          name: trackName,
          channel: trackChannel,
          programNumber: trackProgram,
          notes: trackNotes,
        ));
      }

      return ParsedMidiSong(
        format: format,
        ppqn: ppqn,
        bpm: songBpm,
        timeSignatureNumerator: timeSigNum,
        timeSignatureDenominator: timeSigDenom,
        tracks: parsedTracks,
      );
    } catch (e, stack) {
      debugPrint('MidiFileParser error: $e\n$stack');
      return null;
    }
  }

  static ({int value, int newOffset}) _readVlq(Uint8List bytes, int offset) {
    int value = 0;
    int current = offset;
    while (current < bytes.length) {
      final b = bytes[current++];
      value = (value << 7) | (b & 0x7F);
      if ((b & 0x80) == 0) break;
    }
    return (value: value, newOffset: current);
  }
}
