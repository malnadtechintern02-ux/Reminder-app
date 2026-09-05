import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  final assetDir = Directory('assets/sounds');
  final rawDir = Directory('android/app/src/main/res/raw');

  if (!assetDir.existsSync()) assetDir.createSync(recursive: true);
  if (!rawDir.existsSync()) rawDir.createSync(recursive: true);

  // Clean up existing sound files in raw directory
  if (rawDir.existsSync()) {
    for (final entity in rawDir.listSync()) {
      if (entity is File) {
        entity.deleteSync();
      }
    }
  }

  // Clean up existing sound files in asset directory
  if (assetDir.existsSync()) {
    for (final entity in assetDir.listSync()) {
      if (entity is File) {
        entity.deleteSync();
      }
    }
  }

  final ringtones = [
    'morning_breeze',
    'soft_sunrise',
    'bright_morning',
    'gentle_wake',
    'happy_start',
    'fresh_day',
    'digital_pulse',
    'calm_bell',
    'energy_wake',
    'daily_beat',
    'focus_start',
    'classic_modern',
  ];

  for (int i = 0; i < ringtones.length; i++) {
    final name = ringtones[i];
    final bytes = generateModernRingtonePcmWav(i);

    File('${assetDir.path}/$name.mp3').writeAsBytesSync(bytes);
    File('${rawDir.path}/$name.mp3').writeAsBytesSync(bytes);

    print('Generated modern MP3 audio for $name (${bytes.length} bytes)');
  }
}

Uint8List generateModernRingtonePcmWav(int styleIndex) {
  const sampleRate = 44100;
  const durationSeconds = 3.2;
  final numSamples = (sampleRate * durationSeconds).toInt();
  final samples = Int16List(numSamples);

  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    double sample = 0.0;

    switch (styleIndex % 12) {
      case 0: // Morning Breeze: Smooth ambient marimba melody (E4, G#4, B4, E5)
        final note = ((t * 3.5) % 4).toInt();
        final freqs = [329.63, 415.30, 493.88, 659.25];
        final env = sin(pi * ((t * 3.5) % 1.0));
        sample = (sin(2 * pi * freqs[note] * t) + 0.3 * sin(2 * pi * freqs[note] * 2 * t)) * env * 0.65;
        break;

      case 1: // Soft Sunrise: Gentle chord swell (F#4 + A#4 + C#5)
        final env = sin(pi * (t / durationSeconds));
        sample = (sin(2 * pi * 369.99 * t) + sin(2 * pi * 466.16 * t) + sin(2 * pi * 554.37 * t)) / 3.0 * env * 0.7;
        break;

      case 2: // Bright Morning: Uplifting pentatonic arpeggio (C5, D5, E5, G5, A5)
        final note = ((t * 5) % 5).toInt();
        final freqs = [523.25, 587.33, 659.25, 783.99, 880.00];
        final env = exp(-2.5 * ((t * 5) % 1.0));
        sample = sin(2 * pi * freqs[note] * t) * env * 0.75;
        break;

      case 3: // Gentle Wake: Calming acoustic chime (A4, E5, A5)
        final note = ((t * 3) % 3).toInt();
        final freqs = [440.00, 659.25, 880.00];
        final env = exp(-2.0 * ((t * 3) % 1.0));
        sample = (sin(2 * pi * freqs[note] * t) + 0.4 * sin(2 * pi * freqs[note] * 1.5 * t)) * env * 0.6;
        break;

      case 4: // Happy Start: Upbeat major 7th chime (G4, B4, D5, F#5)
        final note = ((t * 4) % 4).toInt();
        final freqs = [392.00, 493.88, 587.33, 739.99];
        final env = sin(pi * ((t * 4) % 1.0));
        sample = sin(2 * pi * freqs[note] * t) * env * 0.7;
        break;

      case 5: // Fresh Day: Modern synth pop chime
        final step = ((t * 6) % 3).toInt();
        final freqs = [523.25, 659.25, 783.99];
        final env = exp(-3.0 * ((t * 6) % 1.0));
        sample = (sin(2 * pi * freqs[step] * t) + 0.5 * sin(2 * pi * freqs[step] * 2 * t)) * env * 0.7;
        break;

      case 6: // Digital Pulse: Crisp modern electronic pulse
        final pulse = ((t * 6) % 1.0) < 0.35 ? 1.0 : 0.0;
        final freq = ((t * 3).toInt() % 2 == 0) ? 932.33 : 1174.66;
        sample = sin(2 * pi * freq * t) * pulse * 0.65;
        break;

      case 7: // Calm Bell: Crystal clear glass bell toll
        final env = exp(-1.8 * (t % 1.6));
        sample = (sin(2 * pi * 587.33 * t) + 0.5 * sin(2 * pi * 1174.66 * t) + 0.25 * sin(2 * pi * 1761.99 * t)) * env * 0.7;
        break;

      case 8: // Energy Wake: Dynamic rising motif (D4, G4, B4, D5, G5)
        final note = ((t * 6) % 5).toInt();
        final freqs = [293.66, 392.00, 493.88, 587.33, 783.99];
        final env = exp(-2.2 * ((t * 6) % 1.0));
        sample = sin(2 * pi * freqs[note] * t) * env * 0.75;
        break;

      case 9: // Daily Beat: Rhythm chime (C4, F4, G4, C5)
        final note = ((t * 4) % 4).toInt();
        final freqs = [261.63, 349.23, 392.00, 523.25];
        final env = exp(-4.0 * ((t * 4) % 1.0));
        sample = (sin(2 * pi * freqs[note] * t) + 0.3 * sin(2 * pi * freqs[note] * 3 * t)) * env * 0.8;
        break;

      case 10: // Focus Start: Ambient warm synth chord (Bb4, D5, F5, A5)
        final env = sin(pi * (t / durationSeconds));
        sample = (sin(2 * pi * 466.16 * t) + sin(2 * pi * 587.33 * t) + sin(2 * pi * 698.46 * t)) / 3.0 * env * 0.7;
        break;

      case 11: // Classic Modern: Refined modern telephone/clock chime
      default:
        final pulse = ((t * 4) % 1.0) < 0.45 ? 1.0 : 0.0;
        final freq = (t * 2).toInt() % 2 == 0 ? 783.99 : 659.25;
        sample = (sin(2 * pi * freq * t) + 0.4 * sin(2 * pi * freq * 2 * t)) * pulse * 0.7;
        break;
    }

    final clamped = (sample * 32767.0).clamp(-32768.0, 32767.0).toInt();
    samples[i] = clamped;
  }

  // Construct WAV Header (44.1kHz 16-bit Mono PCM)
  final dataSize = numSamples * 2;
  final fileSize = 36 + dataSize;
  final wav = ByteData(44 + dataSize);

  wav.setUint8(0, 0x52); // R
  wav.setUint8(1, 0x49); // I
  wav.setUint8(2, 0x46); // F
  wav.setUint8(3, 0x46); // F
  wav.setUint32(4, fileSize, Endian.little);
  wav.setUint8(8, 0x57);  // W
  wav.setUint8(9, 0x41);  // A
  wav.setUint8(10, 0x56); // V
  wav.setUint8(11, 0x45); // E
  wav.setUint8(12, 0x66); // f
  wav.setUint8(13, 0x6D); // m
  wav.setUint8(14, 0x74); // t
  wav.setUint8(15, 0x20); // ' '
  wav.setUint32(16, 16, Endian.little);
  wav.setUint16(20, 1, Endian.little);
  wav.setUint16(22, 1, Endian.little);
  wav.setUint32(24, sampleRate, Endian.little);
  wav.setUint32(28, sampleRate * 2, Endian.little);
  wav.setUint16(32, 2, Endian.little);
  wav.setUint16(34, 16, Endian.little);
  wav.setUint8(36, 0x64); // d
  wav.setUint8(37, 0x61); // a
  wav.setUint8(38, 0x74); // t
  wav.setUint8(39, 0x61); // a
  wav.setUint32(40, dataSize, Endian.little);

  for (int i = 0; i < numSamples; i++) {
    wav.setInt16(44 + i * 2, samples[i], Endian.little);
  }

  return wav.buffer.asUint8List();
}
