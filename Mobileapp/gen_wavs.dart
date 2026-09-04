import 'dart:convert';
import 'dart:io';

void main() {
  final dir = Directory('android/app/src/main/res/raw');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  
  final base64Wav = 'UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';
  final bytes = base64Decode(base64Wav);
  
  final names = ['morning_alarm', 'classic_alarm', 'digital_alarm', 'gentle_alarm'];
  for (final name in names) {
    File('${dir.path}/$name.wav').writeAsBytesSync(bytes);
  }
  print('Created WAV files');
}
