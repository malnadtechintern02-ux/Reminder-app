import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isAddingRingtone = false;

  @override
  void initState() {
    super.initState();
    _selectedRingtoneId = widget.initialRingtone;
    try {
      AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {},
          ),
        ),
      );
    } catch (e) {
      debugPrint('AudioContext setup error: $e');
    }
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
    setState(() {
      _selectedRingtoneId = ringtoneId;
    });
    if (!widget.isSelectingForReminder) {
      ref.read(settingsNotifierProvider.notifier).setDefaultRingtone(ringtoneId);
    }

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
        if (ringtoneId.startsWith('content://') || ringtoneId.startsWith('http')) {
          await _audioPlayer.play(UrlSource(ringtoneId));
        } else {
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
          try {
            final bytes = await file.readAsBytes();
            await _audioPlayer.play(BytesSource(bytes));
          } catch (bytesErr) {
            debugPrint('BytesSource failed, trying DeviceFileSource: $bytesErr');
            await _audioPlayer.play(DeviceFileSource(ringtoneId));
          }
        }
      } else {
        try {
          await _audioPlayer.play(AssetSource('sounds/$ringtoneId.wav'));
        } catch (_) {
          await _audioPlayer.play(AssetSource('sounds/$ringtoneId.mp3'));
        }
      }

      if (mounted) {
        setState(() {
          _currentlyPlaying = ringtoneId;
          _loadingId = null;
        });
      }
    } catch (e) {
      debugPrint('Error playing sound ($ringtoneId): $e');

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
    if (_isAddingRingtone) return;

    setState(() {
      _isAddingRingtone = true;
    });

    try {
      List<PlatformFile> pickedFiles = [];
      try {
        pickedFiles = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg', 'aac', 'flac', 'opus'],
        );
      } catch (e) {
        debugPrint('Custom file picker error, attempting audio fallback: $e');
        try {
          pickedFiles = await FilePicker.pickFiles(type: FileType.audio);
        } catch (e2) {
          debugPrint('Audio file picker fallback error: $e2');
          pickedFiles = await FilePicker.pickFiles(type: FileType.any);
        }
      }

      if (pickedFiles.isEmpty) {
        // User cancelled picker
        return;
      }

      final picked = pickedFiles.first;

      // Extract and validate extension
      final ext = (picked.extension ?? p.extension(picked.name)).toLowerCase().replaceFirst('.', '');
      const supportedExtensions = ['mp3', 'wav', 'm4a', 'ogg', 'aac', 'flac', 'opus'];
      if (ext.isNotEmpty && !supportedExtensions.contains(ext)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a supported audio file (MP3, WAV, M4A, OGG, AAC, FLAC).'),
            ),
          );
        }
        return;
      }

      // Resolve destination directory safely in app documents
      final docsDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(docsDir.path, 'Ringtones'));

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Determine clean filename
      String originalName = picked.name.isNotEmpty
          ? picked.name
          : (picked.path != null ? p.basename(picked.path!) : 'ringtone.mp3');

      if (p.extension(originalName).isEmpty && ext.isNotEmpty) {
        originalName = '$originalName.$ext';
      }

      // Sanitize filename to remove invalid characters
      String safeName = originalName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      String targetPath = p.join(targetDir.path, safeName);

      // Avoid collision / overwrite
      if (await File(targetPath).exists()) {
        final nameWithoutExt = p.basenameWithoutExtension(safeName);
        final fileExt = p.extension(safeName);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        safeName = '${nameWithoutExt}_$timestamp$fileExt';
        targetPath = p.join(targetDir.path, safeName);
      }

      final targetFile = File(targetPath);

      // Write file data: copy local path if accessible, otherwise read bytes
      bool wroteSuccessfully = false;
      if (picked.path != null && picked.path!.isNotEmpty) {
        try {
          final sourceFile = File(picked.path!);
          if (await sourceFile.exists()) {
            await sourceFile.copy(targetPath);
            wroteSuccessfully = true;
          }
        } catch (copyErr) {
          debugPrint('Direct file copy failed, falling back to byte read: $copyErr');
        }
      }

      if (!wroteSuccessfully) {
        final bytes = await picked.readAsBytes();
        if (bytes.isNotEmpty) {
          await targetFile.writeAsBytes(bytes, flush: true);
          wroteSuccessfully = true;
        }
      }

      if (!wroteSuccessfully || !await targetFile.exists() || (await targetFile.length()) == 0) {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        throw Exception('Unable to read audio data from selected file.');
      }

      // Register custom ringtone in settings
      await ref.read(settingsNotifierProvider.notifier).addCustomRingtone(targetPath);
      
      // Pre-warm MediaStore entry so Android system services can access and play it as an alarm immediately
      try {
        const settingsChannel = MethodChannel('com.reminderapp.reminder_app/settings');
        await settingsChannel.invokeMethod<String>('getMediaUriForFile', {'path': targetPath});
      } catch (e) {
        debugPrint('Pre-warming MediaStore URI error: $e');
      }

      setState(() {
        _selectedRingtoneId = targetPath;
      });

      if (!widget.isSelectingForReminder) {
        await ref.read(settingsNotifierProvider.notifier).setDefaultRingtone(targetPath);
      }

      await _playRingtone(targetPath, isCustom: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added and selected: $safeName')),
        );
      }
    } catch (e) {
      debugPrint('Error adding custom ringtone: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding custom ringtone: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingRingtone = false;
        });
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

  bool _isPopping = false;

  Future<void> _confirmAndPop(String selected) async {
    if (_isPopping) return;
    _isPopping = true;
    await _audioPlayer.stop();
    if (mounted) {
      if (widget.isSelectingForReminder) {
        Navigator.of(context).pop(selected);
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  void _selectRingtone(String id, {bool isCustom = false}) {
    setState(() {
      _selectedRingtoneId = id;
    });
    if (!widget.isSelectingForReminder) {
      ref.read(settingsNotifierProvider.notifier).setDefaultRingtone(id);
    }
    _playRingtone(id, isCustom: isCustom);
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
        await _confirmAndPop(currentSelected);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isSelectingForReminder ? 'Select Alarm Ringtone' : 'Select Ringtone'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _confirmAndPop(currentSelected),
          ),
          actions: [
            if (widget.isSelectingForReminder)
              TextButton(
                onPressed: () => _confirmAndPop(currentSelected),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
          ],
        ),
        bottomNavigationBar: widget.isSelectingForReminder
            ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
                        offset: const Offset(0, -3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmAndPop(currentSelected),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Flexible(
                      child: Text(
                        'Use "${formatRingtoneName(currentSelected)}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              )
            : null,
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
                onSelect: () => _selectRingtone(ringtone.id, isCustom: false),
                onPlay: () => _playRingtone(ringtone.id, isCustom: false),
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
                  'No custom ringtones added yet. Tap "+ Add Ringtone" below to choose an audio file.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ...settings.customRingtones.map((path) {
              final isSelected = currentSelected == path;
              final isPlaying = _currentlyPlaying == path;
              final isLoading = _loadingId == path;
              final name = formatRingtoneName(path);

              return _buildRingtoneCard(
                theme: theme,
                isDarkMode: isDarkMode,
                title: name,
                icon: Icons.music_note_outlined,
                isSelected: isSelected,
                isPlaying: isPlaying,
                isLoading: isLoading,
                onSelect: () => _selectRingtone(path, isCustom: true),
                onPlay: () => _playRingtone(path, isCustom: true),
                onDelete: () => _deleteCustomRingtone(path),
              );
            }),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isAddingRingtone ? null : _addCustomRingtone,
                icon: _isAddingRingtone
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(_isAddingRingtone ? 'Adding Ringtone...' : '+ Add Ringtone'),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
