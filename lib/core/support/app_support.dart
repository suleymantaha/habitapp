import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whatsapp_catalog/core/analytics/app_analytics.dart';
import 'package:whatsapp_catalog/core/ui/app_snackbar.dart';

class AppSupport {
  static const _androidPackageName = 'com.habitapp.whatsapp_catalog';

  static Future<void> restorePurchases(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Satın alımı geri yükle'),
        content: const Text(
          'Bu sürümde uygulama içi satın alma altyapısı aktif değil. '
          'Premium durumu cihaz içi ayarlarda demo olarak yönetiliyor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  static Future<void> rateApp(BuildContext context) async {
    final primary = await _resolveRateUriPrimary();
    final okPrimary = await launchUrl(
      primary,
      mode: LaunchMode.externalApplication,
    );
    if (okPrimary) return;

    final fallback = await _resolveRateUriFallback();
    final okFallback = await launchUrl(
      fallback,
      mode: LaunchMode.externalApplication,
    );
    if (!okFallback && context.mounted) {
      showAppSnackBar(context, 'Mağaza açılamadı.');
    }
  }

  static Future<void> sendFeedback(BuildContext context) async {
    final report = await AppAnalytics.buildReport();
    final text = [
      'Merhaba,',
      '',
      'Aşağıdaki rapor ile birlikte sorunu/öneriyi yazıyorum:',
      '',
      report,
    ].join('\n');

    await SharePlus.instance.share(ShareParams(text: text));
  }

  static Future<Uri> _resolveRateUriPrimary() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Play Store deep-link (önce bunu dene, başarısızsa web fallback var).
      return Uri.parse('market://details?id=$_androidPackageName');
    }
    // iOS için App Store ID yoksa en güvenlisi web araması.
    return Uri.parse('https://www.google.com/search?q=whatsapp+catalog+app');
  }

  static Future<Uri> _resolveRateUriFallback() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return Uri.parse(
        'https://play.google.com/store/apps/details?id=$_androidPackageName',
      );
    }
    return Uri.parse('https://www.google.com/search?q=whatsapp+catalog+app');
  }
}
