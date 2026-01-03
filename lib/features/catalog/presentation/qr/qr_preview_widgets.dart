part of 'qr_preview_page.dart';

class _QrPreviewBody extends StatelessWidget {
  const _QrPreviewBody({
    required this.loading,
    required this.catalog,
    required this.qrData,
    required this.shareText,
    required this.whatsappUrl,
    required this.publishError,
    required this.publishing,
    required this.sharing,
    required this.premiumEnabled,
    required this.appUrl,
    required this.wantsWebMenu,
    required this.isWebMenu,
    required this.primaryIsMenu,
    required this.primaryUrl,
    required this.onOpenPrimary,
    required this.onOpenWhatsApp,
    required this.onCopyLink,
    required this.onShareQrImage,
    required this.onRefreshWebMenu,
    required this.onCopyMessage,
    required this.onOpenStory,
    required this.onOpenPdf,
    required this.qrChild,
  });

  final bool loading;
  final Catalog? catalog;
  final String? qrData;
  final String? shareText;
  final String? whatsappUrl;
  final String? publishError;
  final bool publishing;
  final bool sharing;
  final bool premiumEnabled;
  final String? appUrl;

  final bool wantsWebMenu;
  final bool isWebMenu;
  final bool primaryIsMenu;
  final String? primaryUrl;

  final VoidCallback onOpenPrimary;
  final VoidCallback onOpenWhatsApp;
  final Future<void> Function() onCopyLink;
  final Future<void> Function() onShareQrImage;
  final Future<void> Function() onRefreshWebMenu;
  final Future<void> Function() onCopyMessage;
  final VoidCallback onOpenStory;
  final VoidCallback onOpenPdf;

  final Widget qrChild;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (catalog == null) {
      return const Center(child: Text('Katalog bulunamadı.'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.ios_share,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        catalog!.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'WhatsApp mesajı, QR, Story ve PDF çıktısı al.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if ((shareText ?? '').isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WhatsApp mesajı',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      shareText!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: whatsappUrl == null
                              ? null
                              : onOpenWhatsApp,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('WhatsApp’ı aç'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.tonalIcon(
                        onPressed: onCopyMessage,
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Kopyala'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                qrChild,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: primaryUrl == null ? null : onOpenPrimary,
                        icon: Icon(
                          primaryIsMenu
                              ? Icons.public
                              : Icons.chat_bubble_outline,
                        ),
                        label: Text(
                          primaryIsMenu ? 'Menüyü aç' : 'WhatsApp’ı aç',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Linki kopyala',
                      onPressed: qrData == null ? null : onCopyLink,
                      icon: const Icon(Icons.link),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: sharing || qrData == null ? null : onShareQrImage,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('QR görselini paylaş'),
                ),
                if (wantsWebMenu) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: publishing ? null : onRefreshWebMenu,
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Web menüyü güncelle'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Çıktılar',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: const Text('QR'),
                subtitle: Text(
                  isWebMenu
                      ? 'Müşteri okutunca menü tarayıcıda açılsın'
                      : 'Müşteri okutunca WhatsApp mesajı açılsın',
                ),
                trailing: const Icon(Icons.check),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Instagram Story'),
                subtitle: const Text('Story görseli oluştur ve paylaş'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenStory,
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('A4 PDF'),
                subtitle: const Text('PDF menü oluştur ve paylaş'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenPdf,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.hasQr,
    required this.qrData,
    required this.wantsWebMenu,
    required this.isWebMenu,
    required this.publishError,
    required this.publishing,
    required this.premiumEnabled,
    required this.appUrl,
    required this.primaryIsMenu,
    required this.repaintBoundaryChild,
  });

  final bool hasQr;
  final String? qrData;
  final bool wantsWebMenu;
  final bool isWebMenu;
  final String? publishError;
  final bool publishing;
  final bool premiumEnabled;
  final String? appUrl;
  final bool primaryIsMenu;
  final Widget repaintBoundaryChild;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        repaintBoundaryChild,
        const SizedBox(height: 12),
        Text(
          !hasQr && wantsWebMenu && publishError == null
              ? 'Web menü hazırlanıyor…'
              : isWebMenu
              ? 'Müşteri okutunca menü tarayıcıda açılır.'
              : 'Müşteri okutunca WhatsApp mesajı açılır.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (publishError != null) ...[
          const SizedBox(height: 8),
          Text(
            publishError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (publishing) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (!premiumEnabled) ...[
          const SizedBox(height: 12),
          Text(
            appUrl == null
                ? 'whatsapp_catalog ile oluşturuldu'
                : 'Kendi kataloğunu oluştur: $appUrl',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
