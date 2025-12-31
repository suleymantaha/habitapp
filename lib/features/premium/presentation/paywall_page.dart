import 'package:flutter/material.dart';
import 'package:whatsapp_catalog/core/settings/app_settings.dart';

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  var _didLoad = false;
  var _premiumEnabled = false;

  Future<void> _load() async {
    final enabled = await AppSettings.getPremiumEnabled();
    if (!mounted) return;
    setState(() {
      _premiumEnabled = enabled;
      _didLoad = true;
    });
  }

  Future<void> _setPremium(bool value) async {
    setState(() => _premiumEnabled = value);
    await AppSettings.setPremiumEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_didLoad) _load();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Daha fazla sipariş için Premium', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              value: _premiumEnabled,
              onChanged: _setPremium,
              title: const Text('Premium aktif'),
              subtitle: const Text('Demo: Watermark kapansın, kalite artsın'),
            ),
          ),
          const SizedBox(height: 12),
          _BenefitRow(color: scheme.primary, text: 'Watermark kaldır'),
          _BenefitRow(color: scheme.primary, text: 'Sınırsız ürün/katalog'),
          _BenefitRow(color: scheme.primary, text: 'Tüm şablonlar + sezon temaları'),
          _BenefitRow(color: scheme.primary, text: 'PDF + Story + QR yüksek kalite'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _premiumEnabled ? null : () => _setPremium(true),
            child: const Text('Premium’a geç'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {},
            child: const Text('Satın alımı geri yükle'),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
