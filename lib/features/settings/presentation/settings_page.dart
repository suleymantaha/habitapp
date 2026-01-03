import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:whatsapp_catalog/core/analytics/app_analytics.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Satın alımı geri yükle'),
            onTap: () => AppSupport.restorePurchases(context),
          ),
          ListTile(
            leading: const Icon(Icons.star_rate),
            title: const Text('Uygulamayı puanla'),
            onTap: () async {
              await AppSupport.rateApp(context);
              await AppAnalytics.log('settings_rate_app');
            },
          ),
          ListTile(
            leading: const Icon(Icons.mail),
            title: const Text('Geri bildirim gönder'),
            onTap: () async {
              await AppSupport.sendFeedback(context);
              await AppAnalytics.log('settings_send_feedback');
            },
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            const Divider(),
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
