import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../providers/settings_provider.dart';

class RingtoneSelectionScreen extends ConsumerStatefulWidget {
  const RingtoneSelectionScreen({super.key});

  @override
  ConsumerState<RingtoneSelectionScreen> createState() => _RingtoneSelectionScreenState();
}

class _RingtoneSelectionScreenState extends ConsumerState<RingtoneSelectionScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlaying;
  
  final List<Map<String, String>> _builtInRingtones = [
    {'name': 'Morning Alarm', 'id': 'morning_alarm'},
    {'name': 'Classic Alarm', 'id': 'classic_alarm'},
    {'name': 'Digital Alarm', 'id': 'digital_alarm'},
    {'name': 'Gentle Alarm', 'id': 'gentle_alarm'},
  ];

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playRingtone(String ringtoneId, {bool isCustom = false}) async {
    if (_currentlyPlaying == ringtoneId) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlaying = null);
      return;
    }

    try {
      await _audioPlayer.stop();
      if (isCustom) {
        await _audioPlayer.play(DeviceFileSource(ringtoneId));
      } else {
        await _audioPlayer.play(AssetSource('sounds/$ringtoneId.wav'));
      }
      setState(() => _currentlyPlaying = ringtoneId);
      
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() => _currentlyPlaying = null);
        }
      });
    } catch (e) {
      debugPrint('Error playing sound: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to play ringtone preview.')),
        );
      }
    }
  }

  Future<void> _addCustomRingtone() async {
    try {
      PlatformFile? result = await FilePicker.pickFile(
        type: FileType.audio,
      );

      if (result != null && result.path != null) {
        File sourceFile = File(result.path!);
        
        // Android requires external files directory for Ringtone to be accessible by Notification channels sometimes,
        // or we just copy to external files dir to be safe.
        Directory? externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final ringtoneDir = Directory('${externalDir.path}/Ringtones');
          if (!await ringtoneDir.exists()) {
            await ringtoneDir.create(recursive: true);
          }
          
          final fileName = p.basename(sourceFile.path);
          final targetPath = '${ringtoneDir.path}/$fileName';
          
          await sourceFile.copy(targetPath);
          
          await ref.read(settingsNotifierProvider.notifier).addCustomRingtone(targetPath);
        } else {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Could not access external storage to save ringtone.')),
             );
           }
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error adding custom ringtone.')),
        );
      }
    }
  }

  Future<void> _deleteCustomRingtone(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ringtone?'),
        content: const Text('Are you sure you want to remove this custom ringtone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_currentlyPlaying == path) {
        await _audioPlayer.stop();
        setState(() => _currentlyPlaying = null);
      }
      
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      await ref.read(settingsNotifierProvider.notifier).removeCustomRingtone(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm Sounds'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Text(
              'BUILT-IN',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ..._builtInRingtones.map((ringtone) {
            final isSelected = settings.defaultRingtone == ringtone['id'];
            final isPlaying = _currentlyPlaying == ringtone['id'];
            return _buildRingtoneCard(
              theme: theme,
              isDarkMode: isDarkMode,
              title: ringtone['name']!,
              isSelected: isSelected,
              isPlaying: isPlaying,
              onSelect: () => ref.read(settingsNotifierProvider.notifier).setDefaultRingtone(ringtone['id']!),
              onPlay: () => _playRingtone(ringtone['id']!),
            );
          }),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Text(
              'MY RINGTONES',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (settings.customRingtones.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              child: Text(
                'No custom ringtones added yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ...settings.customRingtones.map((path) {
            final isSelected = settings.defaultRingtone == path;
            final isPlaying = _currentlyPlaying == path;
            final name = p.basename(path);
            return _buildRingtoneCard(
              theme: theme,
              isDarkMode: isDarkMode,
              title: name,
              isSelected: isSelected,
              isPlaying: isPlaying,
              onSelect: () => ref.read(settingsNotifierProvider.notifier).setDefaultRingtone(path),
              onPlay: () => _playRingtone(path, isCustom: true),
              onDelete: () => _deleteCustomRingtone(path),
            );
          }),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _addCustomRingtone,
              icon: const Icon(Icons.add),
              label: const Text('Add Ringtone'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildRingtoneCard({
    required ThemeData theme,
    required bool isDarkMode,
    required String title,
    required bool isSelected,
    required bool isPlaying,
    required VoidCallback onSelect,
    required VoidCallback onPlay,
    VoidCallback? onDelete,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : (isDarkMode ? theme.colorScheme.outline.withValues(alpha: 0.2) : Colors.transparent),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: theme.cardColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          ),
        ),
        onTap: onSelect,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_outline),
              color: isPlaying ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              onPressed: onPlay,
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: theme.colorScheme.error,
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
