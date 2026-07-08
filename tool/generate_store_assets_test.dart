import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 스토어/런처 그래픽 생성기.
///
///   flutter test tool/generate_store_assets_test.dart
///
/// assets/icon/source_art.png(정사각 원본 아트)가 있으면 그걸 크롭해 쓰고,
/// 없으면 코드로 그린 벡터 차트로 폴백한다.
///
/// 생성물:
///   assets/icon/app_icon.png     1024x1024 런처 아이콘 (배경 포함)
///   assets/icon/app_icon_fg.png  1024x1024 어댑티브 전경 (마스크로 33%가 잘리므로
///                                캐릭터 중심 타이트 크롭)
///   docs/store/icon_512.png      Play Console 앱 아이콘
///   docs/store/feature_graphic.png 1024x500 Play 그래픽 이미지
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> savePng(ui.Picture picture, int w, int h, String path) async {
    final image = await picture.toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  }

  // ---- 원본 아트 크롭 경로 ----

  Future<ui.Image?> loadSourceArt() async {
    final f = File('assets/icon/source_art.png');
    if (!f.existsSync()) return null;
    final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
    return (await codec.getNextFrame()).image;
  }

  /// [src]의 [crop] 영역을 [w]x[h]로 그린다.
  ui.Picture cropPicture(ui.Image src, Rect crop, int w, int h) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      src,
      crop,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    return recorder.endRecording();
  }

  // 원본(2048 기준) 크롭 영역. 소스 아트를 바꾸면 여기만 조정한다.
  // 픽셀 테두리·바깥 여백 안쪽의 장면 전체 (라운드 코너의 테두리까지 피함).
  const artScene = Rect.fromLTWH(405, 405, 1240, 1240);
  // 어댑티브 전경: 마스크(중앙 66%) 안에 캐릭터가 온전히 들어오게 타이트 크롭.
  const artCharacter = Rect.fromLTWH(300, 340, 1240, 1240);
  // 그래픽 이미지(2.048:1): 얼굴~차트가 걸치는 중앙 가로 슬라이스.
  const artBanner = Rect.fromLTWH(300, 560, 1450, 708);

  // ---- 벡터 폴백 경로 ----

  const bgTop = Color(0xFF262D33);
  const bgBottom = Color(0xFF14181B);
  const up = Color(0xFFFF5252); // 국장 감성: 빨강 = 상승
  const down = Color(0xFF448AFF);
  const line = Color(0xFF4DB6AC);

  // (cx 0~1, bodyTop 0~1, bodyBottom 0~1, 상승 여부) — 우상향 캔들 4개.
  const candles = [
    (0.14, 0.62, 0.88, true),
    (0.40, 0.52, 0.74, false),
    (0.64, 0.34, 0.62, true),
    (0.88, 0.10, 0.44, true),
  ];

  /// [area] 안에 캔들 4개 + 우상향 화살표를 그린다.
  void drawChart(Canvas canvas, Rect area) {
    final bodyW = area.width * 0.15;
    final wick = Paint()
      ..strokeWidth = area.width * 0.030
      ..strokeCap = StrokeCap.round;
    for (final (cx, top, bottom, isUp) in candles) {
      final color = isUp ? up : down;
      final x = area.left + area.width * cx;
      final bodyTop = area.top + area.height * top;
      final bodyBottom = area.top + area.height * bottom;
      final wickLen = (bodyBottom - bodyTop) * 0.30;
      canvas.drawLine(Offset(x, bodyTop - wickLen),
          Offset(x, bodyBottom + wickLen), wick..color = color);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - bodyW / 2, bodyTop, x + bodyW / 2, bodyBottom),
          Radius.circular(bodyW * 0.22),
        ),
        Paint()..color = color,
      );
    }
    final stroke = area.width * 0.055;
    final path = Path()
      ..moveTo(area.left - stroke, area.top + area.height * 1.02)
      ..lineTo(area.left + area.width * 0.34, area.top + area.height * 0.66)
      ..lineTo(area.left + area.width * 0.52, area.top + area.height * 0.78)
      ..lineTo(area.left + area.width * 0.97, area.top + area.height * 0.12);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final tip = Offset(
        area.left + area.width * 0.97, area.top + area.height * 0.12);
    final head = Path()
      ..moveTo(tip.dx + stroke * 0.9, tip.dy - stroke * 0.9)
      ..lineTo(tip.dx - stroke * 1.6, tip.dy - stroke * 0.4)
      ..lineTo(tip.dx + stroke * 0.4, tip.dy + stroke * 1.6)
      ..close();
    canvas.drawPath(head, Paint()..color = line);
  }

  Paint bgPaint(Rect rect) => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [bgTop, bgBottom],
    ).createShader(rect);

  test('런처 아이콘 1024 (배경 포함)', () async {
    final art = await loadSourceArt();
    final ui.Picture picture;
    if (art != null) {
      picture = cropPicture(art, artScene, 1024, 1024);
    } else {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const rect = Rect.fromLTWH(0, 0, 1024, 1024);
      canvas.drawRect(rect, bgPaint(rect));
      drawChart(canvas, const Rect.fromLTWH(182, 212, 660, 620));
      picture = recorder.endRecording();
    }
    await savePng(picture, 1024, 1024, 'assets/icon/app_icon.png');
  });

  test('어댑티브 전경 1024', () async {
    final art = await loadSourceArt();
    final ui.Picture picture;
    if (art != null) {
      picture = cropPicture(art, artCharacter, 1024, 1024);
    } else {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      drawChart(canvas, Rect.fromCenter(
          center: const Offset(512, 512), width: 520, height: 500));
      picture = recorder.endRecording();
    }
    await savePng(picture, 1024, 1024, 'assets/icon/app_icon_fg.png');
  });

  test('Play 스토어 아이콘 512 + 그래픽 이미지 1024x500', () async {
    final art = await loadSourceArt();
    final ui.Picture icon;
    final ui.Picture banner;
    if (art != null) {
      icon = cropPicture(art, artScene, 512, 512);
      banner = cropPicture(art, artBanner, 1024, 500);
    } else {
      final r1 = ui.PictureRecorder();
      final c1 = Canvas(r1);
      const rect = Rect.fromLTWH(0, 0, 512, 512);
      c1.drawRect(rect, bgPaint(rect));
      drawChart(c1, const Rect.fromLTWH(91, 106, 330, 310));
      icon = r1.endRecording();

      final r2 = ui.PictureRecorder();
      final c2 = Canvas(r2);
      const b = Rect.fromLTWH(0, 0, 1024, 500);
      c2.drawRect(b, bgPaint(b));
      drawChart(c2, const Rect.fromLTWH(560, 70, 400, 360));
      drawChart(c2, const Rect.fromLTWH(120, 170, 260, 240));
      banner = r2.endRecording();
    }
    await savePng(icon, 512, 512, 'docs/store/icon_512.png');
    await savePng(banner, 1024, 500, 'docs/store/feature_graphic.png');
  });
}
