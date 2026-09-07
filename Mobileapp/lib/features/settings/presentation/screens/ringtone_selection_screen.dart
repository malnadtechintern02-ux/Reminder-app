import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../providers/settings_provider.dart';

class RingtoneSelectionScreen extends ConsumerStatefulWidget {
  final String? initialRingtone;
  final bool isSelectingForReminder;

  const RingtoneSelectionScreen({
    super.key,
    this.initialRingtone,
    this.isSelectingForReminder = false,
  });

  @override
  ConsumerState<RingtoneSelectionScreen> createState() => _RingtoneSelectionScreenState();
}

class _RingtoneSelectionScreenState extends ConsumerState<RingtoneSelectionScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlaying;
  String? _loadingId;
  String? _selectedRingtoneId;
  StreamSubscription? _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();
    _selectedRingtoneId = widget.initialRingtone;
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _currentlyPlaying = null;
          _loadingId = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playRingtone(String ringtoneId, {bool isCustom = false}) async {
    if (_currentlyPlaying == ringtoneId) {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _currentlyPlaying = null;
          _loadingId = null;
        });
      }
      return;
    }

    setState(() {
      _loadingId = ringtoneId;
    });

    try {
      await _audioPlayer.stop();
      if (isCustom) {
        final file = File(ringtoneId);
        if (!await file.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Audio file not found on device.')),
            );
            setState(() => _loadingId = null);
          }
          return;
        }
        await _audioPlayer.play(DeviceFileSource(ringtoneId));
      } else {
        await _audioPlayer.play(AssetSource('sounds/$ringtoneId.mp3'));
      }

      if (mounted) {
        setState(() {
          _currentlyPlaying = ringtoneId;
          _loadingId = null;
        });
      }
    } catch (e) {
      debugPrint('Error playing sound ($ringtoneId): $e');
      // Try fallback to wav if mp3 failed
      if (!isCustom) {
        try {
          await _audioPlayer.play(AssetSource('sounds/$ringtoneId.wav'));
          if (mounted) {
            setState(() {
              _currentlyPlaying = ringtoneId;
              _loadingId = null;
            });
          }
          return;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _currentlyPlaying = null;
          _loadingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play ringtone preview: $e')),
        );
      }
    }
  }

  Future<void> _addCustomRingtone() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg'],
      );

      if (result.isNotEmpty) {
        final path = result.first.path;
        if (path == null) return;
        final sourceFile = File(path);


        
        Directory targetDir;
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          targetDir = Directory('${externalDir.path}/Ringtones');
        } else {
          final docsDir = await getApplicationDocumentsDirectory();
          targetDir = Directory('${docsDir.path}/Ringtones');
        }

        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }

        final fileName = p.basename(sourceFile.path);
        final targetPath = '${targetDir.path}/$fileName';

        await sourceFile.copy(targetPath);

        await ref.read(settingsNotifierProvider.notifier).addCustomRingtone(targetPath);
        setState(() {
          _selectedRingtoneId = targetPath;
        });
        if (!widget.isSelectingForReminder) {
          await ref.read(settingsNotifierProvider.notifier).setDefaultRingtone(targetPath);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added custom ringtone: $fileName')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding custom ringtone: $e')),
        );
      }
    }
  }

  Future<void> _deleteCustomRingtone(String path) async {
    final fileName = p.basename(path);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ringtone?'),
        content: Text('Are you sure you want to remove "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_currentlyPlaying == path) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _currentlyPlaying = null);
      }

      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      await ref.read(settingsNotifierProvider.notifier).removeCustomRingtone(path);
      if (_selectedRingtoneId == path) {
        setState(() {
          _selectedRingtoneId = 'morning_breeze';
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ringtone: $fileName')),
        );
      }
    }
  }

  void _selectRingtone(String id) {
    setState(() {
      _selectedRingtoneId = id;
    });
    if (!widget.isSelectingForReminder) {
      ref.read(settingsNotifierProvider.notifier).setDefaultRingtone(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final currentSelected = _selectedRingtoneId ?? settings.defaultRingtone;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _audioPlayer.stop();
        if (context.mounted) {
          if (widget.isSelectingForReminder) {
            Navigator.pop(context, currentSelected);
          } else {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isSelectingForReminder ? 'Select Alarm Ringtone' : 'Select Ringtone'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _audioPlayer.stop();
              if (context.mounted) {
                if (widget.isSelectingForReminder) {
                  Navigator.pop(context, currentSelected);
                } else {
                  Navigator.pop(context);
                }
              }
            },
          ),
          actions: [
            if (widget.isSelectingForReminder)
              TextButton(
                onPressed: () async {
                  await _audioPlayer.stop();
                  if (context.mounted) {
                    Navigator.pop(context, currentSelected);
                  }
                },
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Text(
                'MODERN ALARM TONES',

                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...builtInRingtones.map((ringtone) {
              final isSelected = currentSelected == ringtone.id;
              final isPlaying = _currentlyPlaying == ringtone.id;
              final isLoading = _loadingId == ringtone.id;

              return _buildRingtoneCard(
                theme: theme,
                isDarkMode: isDarkMode,
                title: ringtone.name,
                icon: Icons.notifications_active_outlined,
                isSelected: isSelected,
                isPlaying: isPlaying,
                isLoading: isLoading,
                onSelect: () => _selectRingtone(ringtone.id),
                onPlay: () => _playRingtone(ringtone.id),
              );
            }),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Text(
                'MY RINGTONES',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (settings.customRingtones.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                child: Text(
                  'No custom ringtones added yet. Tap "+ Add Ringtone" below to choose an MP3 file.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ...settings.customRingtones.map((path) {
              final isSelected = currentSelected == path;
              final isPlaying = _currentlyPlaying == path;
              final isLoading = _loadingId == path;
              final name = p.basename(path);

              return _buildRingtoneCard(
                theme: theme,
                isDarkMode: isDarkMode,
                title: name,
                icon: Icons.music_note_outlined,
                isSelected: isSelected,
                isPlaying: isPlaying,
                isLoading: isLoading,
                onSelect: () => _selectRingtone(path),
                onPlay: () => _playRingtone(path, isCustom: true),
                onDelete: () => _deleteCustomRingtone(path),
              );
            }),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _addCustomRingtone,
                icon: const Icon(Icons.add_rounded),
                label: const Text('+ Add Ringtone'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildRingtoneCard({
    required ThemeData theme,
    required bool isDarkMode,
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isPlaying,
    required bool isLoading,
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
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Icon(
              icon,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
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
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              IconButton(
                icon: Icon(isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                color: isPlaying ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                onPressed: onPlay,
                tooltip: isPlaying ? 'Stop' : 'Play',
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: theme.colorScheme.error,
                onPressed: onDelete,
                tooltip: 'Delete custom ringtone',
              ),
          ],
        ),
      ),
    );
  }
}
