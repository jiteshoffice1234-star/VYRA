import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../application/providers/app_providers.dart';
import '../../../application/settings/app_settings.dart';
import '../../../application/settings/theme_provider.dart';
import '../../../application/categories/category_providers.dart';
import '../../../application/habits/habit_providers.dart';
import '../../../application/journal/journal_providers.dart';
import '../../../application/notes/note_providers.dart';
import '../../../application/tags/tag_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme_style.dart';
import '../../../core/theme/vyra_style.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/color_dot.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../data/services/backup_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final settings =
        ref.watch(themeProvider).valueOrNull ?? const AppSettings();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Settings',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          _SectionLabel(title: 'Appearance'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto),
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (s) => ref
                          .read(themeProvider.notifier)
                          .setThemeMode(s.first),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Accent color',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < AppConstants.seedColors.length; i++)
                        ColorDot(
                          size: 42,
                          color: AppConstants.seedColors[i],
                          selected: i == settings.seedIndex,
                          onTap: () =>
                              ref.read(themeProvider.notifier).setSeedIndex(i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Theme style',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final style in AppThemeStyle.values)
                        Expanded(
                          child: _StyleCard(
                            style: style,
                            selected: settings.themeStyle == style,
                            onTap: () => ref
                                .read(themeProvider.notifier)
                                .setThemeStyle(style),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(title: 'Data & Privacy'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: const Text('Export data'),
                  subtitle: const Text(
                      'Save everything to a JSON file on this device'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportData(context, ref),
                ),
                Divider(height: 1, indent: 56, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup & restore'),
                  subtitle: const Text('Create or restore a full backup'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showBackupSheet(context, ref),
                ),
                Divider(height: 1, indent: 56, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy'),
                  subtitle: const Text('How your data is handled'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPrivacy(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(title: 'About'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(
                            'V',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConstants.appName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Version ${AppConstants.appVersion}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.favorite, color: Colors.pink, size: 20),
                    ],
                  ),
                ),
                Divider(height: 1, indent: 20, endIndent: 20),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About VYRA'),
                  subtitle: const Text(AppConstants.tagline),
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'All data stays on your device · No account needed',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      final service = await ref.read(backupServiceProvider.future);
      final result = await service.export();
      if (!context.mounted) return;
      if (result.skippedDuplicate) {
        showAppSnackBar(
          context,
          'An identical backup already exists — nothing new was saved.',
        );
      } else {
        showAppSnackBar(context, 'Exported to:\n${result.path}');
      }
    } catch (e, st) {
      AppLogger.error('Failed to export data', e, st);
      if (context.mounted) {
        showAppSnackBar(context, 'Could not export your data.');
      }
    }
  }

  Future<void> _showBackupSheet(BuildContext context, WidgetRef ref) async {
    final service = await ref.read(backupServiceProvider.future);
    if (!context.mounted) return;
    final backups = await service.listBackups();
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Backup & restore',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Import backup',
                    icon: const Icon(Icons.drive_folder_upload_outlined),
                    onPressed: () => _importBackup(context, ref, service),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      final result = await service.export();
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      showAppSnackBar(
                        context,
                        result.skippedDuplicate
                            ? 'An identical backup already exists.'
                            : 'Backup created:\n${result.path}',
                      );
                    } catch (e, st) {
                      AppLogger.error('Failed to create backup', e, st);
                      if (context.mounted) {
                        showAppSnackBar(
                            context, 'Could not create the backup.');
                      }
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create new backup'),
                ),
              ),
              const SizedBox(height: 16),
              if (backups.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'No backups yet. Create one to get started.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else ...[
                Text(
                  'Restore from backup',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: backups.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final info = backups[index];
                      return ListTile(
                        dense: true,
                        leading: info.valid
                            ? const Icon(Icons.description_outlined)
                            : Icon(
                                Icons.error_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                        title: Text(
                          info.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          info.valid
                              ? '${info.rowCount} rows'
                                  '${info.exportedAt != null ? ' · ${AppDate.formatMedium(info.exportedAt!)}' : ''}'
                              : (info.error ?? 'Unreadable backup'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete backup',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              _deleteBackup(context, service, info),
                        ),
                        onTap: () => _confirmRestore(
                          context,
                          ref,
                          service,
                          File(info.path),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRestore(
    BuildContext context,
    WidgetRef ref,
    BackupService service,
    File file,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Restore this backup?',
      message: 'All current journals, habits and notes will be replaced '
          'with the contents of this backup. This cannot be undone.',
      confirmLabel: 'Restore',
    );
    if (!ok || !context.mounted) return;
    try {
      await service.restoreFile(file);
      // Restore writes the database directly, so reminders are re-scheduled
      // from the restored rows (best-effort; never fails the restore).
      await ref.read(habitsProvider.notifier).resyncReminders();
      _refreshAll(ref);
      if (context.mounted) {
        // Close the sheet first so the restored data is visible underneath.
        Navigator.of(context).pop();
        showAppSnackBar(context, 'Backup restored successfully.');
      }
    } catch (e, st) {
      AppLogger.error('Failed to restore backup', e, st);
      if (context.mounted) {
        showAppSnackBar(
          context,
          e is BackupException ? e.message : 'Could not restore the backup.',
        );
      }
    }
  }

  /// Import flow: pick a local JSON backup, validate it, then restore with
  /// confirmation — never overwrites data without explicit consent.
  Future<void> _importBackup(
    BuildContext context,
    WidgetRef ref,
    BackupService service,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'vyra_backups'));
    if (!await dir.exists()) {
      if (context.mounted) {
        showAppSnackBar(context, 'No backups found on this device.');
      }
      return;
    }
    // Async streaming listing so the import flow never blocks the UI thread.
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File &&
          p.extension(entity.path).toLowerCase() == '.json') {
        files.add(entity);
      }
    }
    files.sort((a, b) => b.path.compareTo(a.path));
    if (files.isEmpty) {
      if (context.mounted) {
        showAppSnackBar(context, 'No backups found on this device.');
      }
      return;
    }
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<File>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Import backup',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a JSON backup on this device to restore.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: files.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final f = files[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.upload_file_outlined),
                      title: Text(
                        f.path.split(RegExp(r'[\\\\/]')).last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(_formatBytes(f.lengthSync())),
                      onTap: () => Navigator.of(ctx).pop(f),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    try {
      final info = await service.inspect(picked);
      if (!context.mounted) return;
      if (!info.valid) {
        showAppSnackBar(
          context,
          info.error ?? 'This file is not a valid backup.',
        );
        return;
      }
      _confirmRestore(context, ref, service, picked);
    } catch (e, st) {
      AppLogger.error('Failed to inspect import file', e, st);
      if (context.mounted) {
        showAppSnackBar(context, 'Could not read that backup file.');
      }
    }
  }

  Future<void> _deleteBackup(
    BuildContext context,
    BackupService service,
    BackupInfo info,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Delete this backup?',
      message: '${info.fileName} will be permanently removed. '
          'Your current data is not affected.',
      confirmLabel: 'Delete',
    );
    if (!ok || !context.mounted) return;
    try {
      await service.deleteBackup(info.path);
      if (context.mounted) showAppSnackBar(context, 'Backup deleted.');
    } catch (e, st) {
      AppLogger.error('Failed to delete backup', e, st);
      if (context.mounted) {
        showAppSnackBar(context, 'Could not delete the backup.');
      }
    }
  }

  /// Reloads every data provider after a restore so all screens show the
  /// restored data immediately.
  void _refreshAll(WidgetRef ref) {
    ref.invalidate(categoriesProvider);
    ref.invalidate(tagProvider);
    ref.invalidate(journalListProvider);
    ref.invalidate(habitsProvider);
    ref.invalidate(notesProvider);
    // Restore preserves habit ids, so the cached grouped counts would
    // otherwise keep showing pre-restore data forever.
    ref.invalidate(habitCountsMapProvider);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showPrivacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy'),
        content: const Text(
          'VYRA is 100% offline. Your journals, habits and notes are stored '
          'only in a local database on this device. Nothing is uploaded, '
          'tracked or shared — ever.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: Text(
                  'V',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              AppConstants.appName,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Version ${AppConstants.appVersion}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              AppConstants.tagline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Built with Flutter · SQLite · Riverpod',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final AppThemeStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vStyle = VyraStyle.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 52,
              decoration: _swatch(scheme, vStyle),
            ),
            const SizedBox(height: 8),
            Text(
              style.label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _swatch(ColorScheme scheme, VyraStyle vStyle) {
    switch (style) {
      case AppThemeStyle.modern:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(vStyle.radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.tertiary],
          ),
        );
      case AppThemeStyle.neobrutalism:
        return BoxDecoration(
          color: const Color(0xFFF7F1E5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF111111), width: 2.5),
          boxShadow: const [
            BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3)),
          ],
        );
      case AppThemeStyle.glass:
        return BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 14,
            ),
          ],
        );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
