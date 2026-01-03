import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:whatsapp_catalog/app/app_scope.dart';
import 'package:whatsapp_catalog/core/analytics/app_analytics.dart';
import 'package:whatsapp_catalog/core/settings/app_settings.dart';
import 'package:whatsapp_catalog/core/support/app_support.dart';
import 'package:whatsapp_catalog/core/ui/app_snackbar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  var _sharingReport = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _copyAnalyticsReport() async {
    final text = await AppAnalytics.buildReport();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showAppSnackBar(context, 'Rapor kopyalandı.');
  }

  Future<void> _shareAnalyticsReport() async {
    if (_sharingReport) return;
    setState(() => _sharingReport = true);
    try {
      final text = await AppAnalytics.buildReport();
      await SharePlus.instance.share(ShareParams(text: text));
    } finally {
      if (mounted) setState(() => _sharingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = AppScope.of(context).themeMode;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Görünüm',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tema',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeMode,
                    builder: (context, mode, _) {
                      return SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_outlined),
                            label: Text('Oto'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined),
                            label: Text('Açık'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined),
                            label: Text('Koyu'),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (selection) {
                          final next = selection.first;
                          themeMode.value = next;
                          unawaited(AppSettings.setThemeMode(next));
                          unawaited(
                            AppAnalytics.log('settings_theme_${next.name}'),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '“Oto” cihaz ayarını kullanır.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Genel',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('Satın alımı geri yükle'),
                  onTap: () => AppSupport.restorePurchases(context),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.star_rate),
                  title: const Text('Uygulamayı puanla'),
                  onTap: () async {
                    await AppSupport.rateApp(context);
                    await AppAnalytics.log('settings_rate_app');
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.mail),
                  title: const Text('Geri bildirim gönder'),
                  onTap: () async {
                    await AppSupport.sendFeedback(context);
                    await AppAnalytics.log('settings_send_feedback');
                  },
                ),
              ],
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            Text(
              'Gelişmiş (debug)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Ölçümleme raporu (cihaz içi).'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copyAnalyticsReport,
                            icon: const Icon(Icons.copy_all_outlined),
                            label: const Text('Kopyala'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _sharingReport
                                ? null
                                : _shareAnalyticsReport,
                            icon: const Icon(Icons.ios_share),
                            label: const Text('Paylaş'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
