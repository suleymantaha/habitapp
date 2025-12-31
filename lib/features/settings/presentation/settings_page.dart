import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:whatsapp_catalog/core/analytics/app_analytics.dart';
import 'package:whatsapp_catalog/core/settings/app_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _shareUrlController = TextEditingController();
  final _publicMenuBaseUrlController = TextEditingController();
  var _didLoad = false;
  var _saving = false;
  var _sharingReport = false;

  @override
  void dispose() {
    _shareUrlController.dispose();
    _publicMenuBaseUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final url = await AppSettings.getShareAppUrl();
    final publicBaseUrl = await AppSettings.getPublicMenuBaseUrl();
    if (!mounted) return;
    _shareUrlController.text = url ?? '';
    _publicMenuBaseUrlController.text = publicBaseUrl ?? '';
    setState(() => _didLoad = true);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AppSettings.setShareAppUrl(_shareUrlController.text);
      await AppSettings.setPublicMenuBaseUrl(_publicMenuBaseUrlController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Kaydedildi.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copyAnalyticsReport() async {
    final text = await AppAnalytics.buildReport();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Rapor kopyalandı.')));
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
    if (!_didLoad) _load();
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Paylaşım linki',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _shareUrlController,
            decoration: const InputDecoration(
              hintText: 'https://... (App Store / Play Store / landing)',
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          Text(
            'Web menü servisi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _publicMenuBaseUrlController,
            decoration: const InputDecoration(
              hintText: 'https://....workers.dev',
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Kaydet'),
          ),
          const SizedBox(height: 20),
          Text(
            'Ölçümleme',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Funnel event sayımları (cihaz içi).'),
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
                          onPressed: _sharingReport ? null : _shareAnalyticsReport,
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
          const SizedBox(height: 20),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.restore),
            title: Text('Satın alımı geri yükle'),
          ),
          const ListTile(
            leading: Icon(Icons.star_rate),
            title: Text('Uygulamayı puanla'),
          ),
          const ListTile(
            leading: Icon(Icons.mail),
            title: Text('Geri bildirim gönder'),
          ),
        ],
      ),
    );
  }
}
