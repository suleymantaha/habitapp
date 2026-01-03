part of 'qr_preview_page.dart';

extension _QrPreviewPageStateActions on _QrPreviewPageState {
  Future<Uint8List?> _captureQrPngBytes() async {
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = _qrRepaintKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final image = await renderObject.toImage(
      pixelRatio: _premiumEnabled ? 4 : 3,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _shareQrImage() async {
    if (_sharing) return;
    final data = _qrData;
    if (data == null) return;

    _safeSetState(() => _sharing = true);
    try {
      final bytes = await _captureQrPngBytes();
      if (bytes == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qr_${widget.args.catalogId}.png');
      await file.writeAsBytes(bytes, flush: true);

      final referral = await buildReferralShareText();
      await AppAnalytics.log('qr_share_image');
      await SharePlus.instance.share(
        ShareParams(text: referral, files: [XFile(file.path)]),
      );
    } finally {
      _safeSetState(() => _sharing = false);
    }
  }

  Future<void> _load() async {
    _safeSetState(() => _loading = true);
    final catalog = await _repo.getCatalog(widget.args.catalogId);
    if (!mounted) return;
    if (catalog == null) {
      _safeSetState(() {
        _loading = false;
        _catalog = null;
        _qrData = null;
        _shareText = null;
        _whatsappUrl = null;
      });
      return;
    }
    final text = buildCatalogShareText(
      catalogName: catalog.name,
      currencyCode: catalog.currencyCode,
      items: [
        for (final i in catalog.items)
          CatalogShareItem(title: i.title, price: i.price),
      ],
    );
    final url = buildWhatsAppSendUrl(text: text);
    final baseUrl = _publicMenuBaseUrl;
    final wantsWebMenu = baseUrl != null && baseUrl.isNotEmpty;
    _safeSetState(() {
      _loading = false;
      _catalog = catalog;
      _shareText = text;
      _whatsappUrl = url;
      _qrData = wantsWebMenu ? null : url;
    });
    unawaited(_ensurePublished());
    _maybeAutoOpenHtml();
  }

  Future<void> _ensurePublished() async {
    final baseUrl = _publicMenuBaseUrl;
    final catalog = _catalog;
    if (baseUrl == null || baseUrl.isEmpty) return;
    if (_publishing) return;
    if (catalog == null) return;

    _safeSetState(() {
      _publishing = true;
      _publishError = null;
    });
    try {
      final client = PublicMenuClient(baseUrl: baseUrl);
      final existing = await PublicMenuLinkStore.get(catalog.id);
      if (existing == null) {
        final created = await client.createMenu(catalog);
        final link = PublicMenuLink(
          id: created.id,
          editToken: created.editToken,
        );
        await PublicMenuLinkStore.set(catalog.id, link);
        final url = client.publicUrlForId(created.id);
        if (!mounted) return;
        _safeSetState(() => _qrData = url);
        _maybeAutoOpenHtml();
      } else {
        await client.updateMenu(
          id: existing.id,
          editToken: existing.editToken,
          catalog: catalog,
        );
        final url = client.publicUrlForId(existing.id);
        if (!mounted) return;
        _safeSetState(() => _qrData = url);
        _maybeAutoOpenHtml();
      }
    } on Exception {
      if (!mounted) return;
      final fallback = _whatsappUrl;
      _safeSetState(() {
        _publishError =
            'Web menü yayınlanamadı. Ayarlar → “Web menü servisi” alanını kontrol et.';
        if (fallback != null) _qrData = fallback;
      });
    } finally {
      _safeSetState(() => _publishing = false);
    }
  }

  void _maybeAutoOpenHtml() {
    if (!widget.args.autoOpenHtml) return;
    if (_didAutoOpen) return;
    final catalog = _catalog;
    if (catalog == null) return;
    final primaryUrl = _computePrimaryUrl();
    if (primaryUrl == null) return;

    _didAutoOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_openHtmlView());
    });
  }

  String? _computePrimaryUrl() {
    final wantsWebMenu = (_publicMenuBaseUrl ?? '').isNotEmpty;
    final primaryIsMenu = wantsWebMenu && _publishError == null;
    return primaryIsMenu ? _qrData : _whatsappUrl;
  }

  bool get _isWebMenu {
    return _whatsappUrl != null && _qrData != null && _qrData != _whatsappUrl;
  }

  String _buildCatalogHtml(Catalog catalog) {
    const esc = HtmlEscape();
    final title = esc.convert(catalog.name);
    final currencyCode = esc.convert(catalog.currencyCode);

    final items = catalog.items
        .map((i) {
          final itemTitle = esc.convert(i.title);
          final price = esc.convert(
            formatMoney(value: i.price, currencyCode: catalog.currencyCode),
          );
          final description = esc.convert(i.description);
          final section = esc.convert((i.section ?? '').trim());
          final subsection = esc.convert((i.subsection ?? '').trim());

          final meta = [
            if (section.isNotEmpty) section,
            if (subsection.isNotEmpty) subsection,
          ].join(' / ');

          return '''
<li class="item">
  <div class="row">
    <div class="name">$itemTitle</div>
    <div class="price">$price</div>
  </div>
  ${meta.isNotEmpty ? '<div class="meta">$meta</div>' : ''}
  ${description.isNotEmpty ? '<div class="desc">$description</div>' : ''}
</li>
''';
        })
        .join('\n');

    return '''
<!doctype html>
<html lang="tr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>$title</title>
  <style>
    :root { color-scheme: light dark; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; margin: 0; padding: 16px; }
    h1 { margin: 0 0 8px 0; font-size: 22px; }
    .sub { opacity: 0.7; margin: 0 0 16px 0; }
    ul { list-style: none; padding: 0; margin: 0; display: grid; gap: 10px; }
    .item { border: 1px solid rgba(127,127,127,.25); border-radius: 12px; padding: 12px; }
    .row { display: flex; gap: 12px; justify-content: space-between; align-items: baseline; }
    .name { font-weight: 700; }
    .price { font-weight: 700; white-space: nowrap; }
    .meta { opacity: 0.7; font-size: 12px; margin-top: 4px; }
    .desc { margin-top: 6px; white-space: pre-wrap; }
  </style>
</head>
<body>
  <h1>$title</h1>
  <p class="sub">$currencyCode</p>
  <ul>
    $items
  </ul>
</body>
</html>
''';
  }

  Future<void> _openHtmlView() async {
    final isWebMenu = _isWebMenu;
    final menuUrl = _qrData;

    await AppAnalytics.log('qr_html_open');

    if (isWebMenu && menuUrl != null && menuUrl.isNotEmpty) {
      final ok = await launchUrl(
        Uri.parse(menuUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!ok) {
        showAppSnackBar(context, 'Menü açılamadı.');
      }
      return;
    }

    final catalog = _catalog;
    if (catalog == null) return;
    final html = _buildCatalogHtml(catalog);
    final uri = Uri.dataFromString(html, mimeType: 'text/html', encoding: utf8);

    final ok = await launchUrl(uri);
    if (!mounted) return;

    if (ok) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HTML'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(html)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await Clipboard.setData(ClipboardData(text: html));
              if (!mounted) return;
              showAppSnackBar(this.context, 'HTML kopyalandı.');
            },
            child: const Text('Kopyala'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}
