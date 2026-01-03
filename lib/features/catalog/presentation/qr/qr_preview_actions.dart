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
        _publishError = null;
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
      _publishError = null;
      _qrData = wantsWebMenu ? null : url;
    });
    unawaited(_ensurePublished());
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
      } else {
        await client.updateMenu(
          id: existing.id,
          editToken: existing.editToken,
          catalog: catalog,
        );
        final url = client.publicUrlForId(existing.id);
        if (!mounted) return;
        _safeSetState(() => _qrData = url);
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

  String? _computePrimaryUrl() {
    final wantsWebMenu = (_publicMenuBaseUrl ?? '').isNotEmpty;
    final primaryIsMenu = wantsWebMenu && _publishError == null;
    return primaryIsMenu ? _qrData : _whatsappUrl;
  }

  bool get _isWebMenu {
    return _whatsappUrl != null && _qrData != null && _qrData != _whatsappUrl;
  }
}
