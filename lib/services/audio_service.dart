import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

abstract class AudioService {
  factory AudioService() = _AudioServiceImpl;
  const AudioService._();

  Future<void> playExerciseStart();
  Future<void> playMetronomeAccent();
  Future<void> playMetronomeTick();
  Future<void> playTimerDone();
  Future<void> playSetComplete();
  void dispose();
}

class _AudioServiceImpl extends AudioService {
  final AudioPlayer _player = AudioPlayer();

  _AudioServiceImpl() : super._();

  @override
  Future<void> playExerciseStart() async {
    final wav1 = _generateWav(hz: 600, durationMs: 120, amplitude: 0.45);
    await _playWav(wav1);
    await Future.delayed(const Duration(milliseconds: 60));
    final wav2 = _generateWav(hz: 900, durationMs: 320, amplitude: 0.55);
    await _playWav(wav2);
  }

  @override
  Future<void> playTimerDone() async {
    final wav = _generateWav(hz: 880, durationMs: 600, amplitude: 0.5);
    await _playWav(wav);
  }

  @override
  Future<void> playMetronomeAccent() async {
    final wav = _generateWav(hz: 1500, durationMs: 60, amplitude: 0.45);
    await _playWav(wav);
  }

  @override
  Future<void> playMetronomeTick() async {
    final wav = _generateWav(hz: 750, durationMs: 45, amplitude: 0.3);
    await _playWav(wav);
  }

  @override
  Future<void> playSetComplete() async {
    final wav1 = _generateWav(hz: 880, durationMs: 250, amplitude: 0.5);
    await _playWav(wav1);
    await Future.delayed(const Duration(milliseconds: 100));
    final wav2 = _generateWav(hz: 1100, durationMs: 400, amplitude: 0.5);
    await _playWav(wav2);
  }

  Future<void> _playWav(Uint8List data) async {
    try {
      await _player.play(BytesSource(data));
      await _player.onPlayerComplete.first.timeout(const Duration(seconds: 5));
    } catch (_) {
      // Audio may not be available in all environments; fail silently.
    }
  }

  Uint8List _generateWav({
    required int hz,
    required int durationMs,
    double amplitude = 0.5,
  }) {
    const sampleRate = 44100;
    const numChannels = 1;
    const bitsPerSample = 16;
    final numSamples = sampleRate * durationMs ~/ 1000;
    final dataSize = numSamples * numChannels * (bitsPerSample ~/ 8);
    final totalSize = 44 + dataSize;

    final buffer = ByteData(totalSize);
    int offset = 0;

    _writeAscii(buffer, offset, 'RIFF'); offset += 4;
    buffer.setUint32(offset, totalSize - 8, Endian.little); offset += 4;
    _writeAscii(buffer, offset, 'WAVE'); offset += 4;

    _writeAscii(buffer, offset, 'fmt '); offset += 4;
    buffer.setUint32(offset, 16, Endian.little); offset += 4;
    buffer.setUint16(offset, 1, Endian.little); offset += 2;
    buffer.setUint16(offset, numChannels, Endian.little); offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little); offset += 4;
    buffer.setUint32(offset, sampleRate * numChannels * (bitsPerSample ~/ 8), Endian.little); offset += 4;
    buffer.setUint16(offset, numChannels * (bitsPerSample ~/ 8), Endian.little); offset += 2;
    buffer.setUint16(offset, bitsPerSample, Endian.little); offset += 2;

    _writeAscii(buffer, offset, 'data'); offset += 4;
    buffer.setUint32(offset, dataSize, Endian.little); offset += 4;

    final fadeStartSample = (numSamples * 0.9).toInt();
    for (int i = 0; i < numSamples; i++) {
      double sample = math.sin(2 * math.pi * hz * i / sampleRate);
      if (i >= fadeStartSample) {
        final fadeProgress = (i - fadeStartSample) / (numSamples - fadeStartSample);
        sample *= (1.0 - fadeProgress);
      }
      final intSample = (sample * amplitude * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(offset, intSample, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }

  void _writeAscii(ByteData buffer, int offset, String text) {
    for (int i = 0; i < text.length; i++) {
      buffer.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  @override
  void dispose() => _player.dispose();
}
