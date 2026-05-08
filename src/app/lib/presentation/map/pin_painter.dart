import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Renders price-tier pin bitmaps for the Mapbox station symbol layer.
///
/// Pins are 128 × 56 px at 2× pixel ratio (64 × 28 dp displayed). Each pin
/// consists of a colored rounded-rectangle body with a gas-pump icon on the
/// left, a vertical divider, a price label on the right, all in one row, and
/// a downward triangular pointer at the bottom centre.
///
/// Callers own the registration cache ([pinImageId] / [fallbackIconId]) and
/// the Mapbox SDK; this class only produces raw PNG bytes.
abstract final class PinPainter {
  /// Canvas width in physical pixels (2× → 64 dp displayed).
  static const int width = 128;

  /// Canvas height in physical pixels (2× → 28 dp displayed).
  static const int height = 56;

  static const double _bodyH = 44.0;
  static const double _cornerR = 10.0;

  /// Cached decoded image for [_iconAssetPath]. Loaded once on first render.
  static ui.Image? _cachedIconImage;

  static const String _iconAssetPath = 'assets/brands/default_gas_icon.png';

  /// Width of the icon section on the left of the pin body.
  static const double _iconSectionW = 44.0;

  // 4 price-tier background colours.
  // 0 = cheapest (green), 1 = low-mid (yellow), 2 = high-mid (orange),
  // 3 = most expensive (red).
  static const List<ui.Color> tierColors = [
    ui.Color(0xFF27AE60), // green
    ui.Color(0xFFF1C40F), // yellow
    ui.Color(0xFFE67E22), // orange
    ui.Color(0xFFE74C3C), // red
  ];

  /// Image ID used as a fallback when [render] fails (e.g. on the SW emulator).
  /// The actual fallback images are registered at init time via [render] with
  /// an empty [priceLabel] for each tier.
  static const String fallbackIconId = 'gas-icon';

  /// Returns the Mapbox style image ID for a given [tier] + [label] pair.
  ///
  /// The ID is safe for use as a Mapbox image key (no dots or cent signs).
  static String pinImageId(int tier, String label) =>
      'pin_${tier}_${label.replaceAll('.', 'd').replaceAll('¢', 'c')}';

  /// Renders a single pin bitmap for [tier] with [priceLabel] and returns the
  /// PNG bytes, or `null` if rendering fails (caller uses fallback).
  ///
  /// Layout (128 × 56 px canvas, declared as 2× → 64 × 28 dp):
  /// - Drop shadow (offset rect, no blur)
  /// - Rounded rectangle body (128 × 44 px) in the tier background colour
  /// - Gas-pump silhouette in the left 44 px section
  /// - Vertical divider
  /// - Price label centred in the right section
  /// - Downward triangle pointer at the bottom centre
  static Future<Uint8List?> render({
    required int tier,
    required String priceLabel,
  }) async {
    try {
      final w = width.toDouble();
      const bodyH = _bodyH;
      const tipH = height - _bodyH;
      const r = _cornerR;
      final bg = tierColors[tier];

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Rounded rectangle body.
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(0, 0, w, bodyH),
          const ui.Radius.circular(r),
        ),
        ui.Paint()..color = bg,
      );

      // Downward pointer triangle.
      canvas.drawPath(
        ui.Path()
          ..moveTo(w / 2 - 9, bodyH - 1)
          ..lineTo(w / 2 + 9, bodyH - 1)
          ..lineTo(w / 2, bodyH + tipH)
          ..close(),
        ui.Paint()..color = bg,
      );

      // Gas pump icon on the left section.
      // _cachedIconImage is populated by preloadIcon() before rendering begins.
      final iconImg = _cachedIconImage;
      if (iconImg != null) {
        const iconSize = _iconSectionW * 0.62;
        const iconX = (_iconSectionW - iconSize) / 2;
        const iconY = (_bodyH - iconSize) / 2;
        final src = ui.Rect.fromLTWH(
          0,
          0,
          iconImg.width.toDouble(),
          iconImg.height.toDouble(),
        );
        const dst = ui.Rect.fromLTWH(iconX, iconY, iconSize, iconSize);
        canvas.drawImageRect(
          iconImg,
          src,
          dst,
          ui.Paint()
            ..colorFilter = const ui.ColorFilter.mode(
              ui.Color(0xCCFFFFFF),
              ui.BlendMode.srcIn,
            ),
        );
      } else {
        _drawGasPumpIcon(canvas);
      }

      // Price label centred in the right section.
      const priceSectionX = _iconSectionW;
      final priceSectionW = w - priceSectionX;
      final pb =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(textAlign: ui.TextAlign.center, maxLines: 1),
            )
            ..pushStyle(
              ui.TextStyle(
                color: const ui.Color(0xFFFFFFFF),
                fontSize: 20.0,
                fontWeight: ui.FontWeight.bold,
              ),
            )
            ..addText(priceLabel.isEmpty ? '–' : priceLabel);
      final para = pb.build()
        ..layout(ui.ParagraphConstraints(width: priceSectionW));
      canvas.drawParagraph(
        para,
        ui.Offset(priceSectionX, (bodyH - para.height) / 2),
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(width, height);
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      return bd?.buffer.asUint8List();
    } catch (_) {
      return null; // Caller registers the fallback icon instead.
    }
  }

  /// Pre-loads the gas-pump icon asset and stores it in [_cachedIconImage].
  /// Call this once before any [render] calls so that rendering is not
  /// interrupted by a platform channel round-trip mid-draw.
  static Future<void> preloadIcon() async {
    await _loadIconImage();
  }

  /// Loads and caches [_iconAssetPath] as a [ui.Image].
  /// Returns `null` if the asset cannot be decoded (caller falls back to the
  /// programmatic silhouette).
  static Future<ui.Image?> _loadIconImage() async {
    if (_cachedIconImage != null) return _cachedIconImage;
    try {
      final data = await rootBundle.load(_iconAssetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _cachedIconImage = frame.image;
      return _cachedIconImage;
    } catch (_) {
      return null;
    }
  }

  /// Draws a simplified gas-pump silhouette centred in the left icon section
  /// of the pin body. Used as fallback when the PNG asset cannot be loaded.
  static void _drawGasPumpIcon(ui.Canvas canvas) {
    final paint = ui.Paint()..color = const ui.Color(0xCCFFFFFF);

    // Scale factor: icon drawn in a 28×28 space centred in the icon section.
    const s = 1.35; // scale relative to 20 px unit
    // Centre the icon horizontally within the icon section.
    const cx = _iconSectionW / 2 - 7 * s;
    // Centre the icon vertically within the body.
    const cy = (_bodyH - (4 * s + 17 * s)) / 2 - 4 * s;

    // Main body rectangle.
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(cx, cy + 4 * s, 14 * s, 17 * s),
        ui.Radius.circular(2 * s),
      ),
      paint,
    );

    // Screen / display window inside the body.
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(cx + 2 * s, cy + 6 * s, 10 * s, 6 * s),
        ui.Radius.circular(1 * s),
      ),
      ui.Paint()..color = const ui.Color(0x88FFFFFF),
    );

    // Nozzle arm (rounded rect, rotated via translate+rotate).
    canvas.save();
    canvas.translate(cx + 17 * s, cy + 7 * s);
    canvas.rotate(0.3);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(0, 0, 2.5 * s, 9 * s),
        ui.Radius.circular(1.5 * s),
      ),
      paint,
    );
    canvas.restore();

    // Nozzle tip.
    canvas.drawCircle(ui.Offset(cx + 19.5 * s, cy + 5 * s), 2 * s, paint);
  }
}
