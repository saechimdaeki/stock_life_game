import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 스토어/런처 그래픽 생성기. 아트 에셋이 생기기 전까지 쓰는 코드 폴백.
///
///   flutter test tool/generate_store_assets_test.dart
///
/// 생성물:
///   assets/icon/app_icon.png     1024x1024 런처 아이콘 (배경 포함)
///   assets/icon/app_icon_fg.png  1024x1024 어댑티브 전경 (투명 배경, 세이프존)
///   docs/store/icon_512.png      Play Console 앱 아이콘
///   docs/store/feature_graphic.png 1024x500 Play 그래픽 이미지
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  void drawChart(Canvas canvas, Rect area, {double scale = 1}) {
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
    // 우상향 라인 + 화살촉.
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

  Future<void> savePng(ui.Picture picture, int w, int h, String path) async {
    final image = await picture.toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  }

  Paint bgPaint(Rect rect) => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [bgTop, bgBottom],
    ).createShader(rect);

  test('런처 아이콘 1024 (배경 포함)', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const rect = Rect.fromLTWH(0, 0, 1024, 1024);
    canvas.drawRect(rect, bgPaint(rect));
    drawChart(canvas, const Rect.fromLTWH(182, 212, 660, 620));
    await savePng(recorder.endRecording(), 1024, 1024,
        'assets/icon/app_icon.png');
  });

  test('어댑티브 전경 1024 (투명 배경, 세이프존 66%)', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    drawChart(canvas, Rect.fromCenter(
        center: const Offset(512, 512), width: 520, height: 500));
    await savePng(recorder.endRecording(), 1024, 1024,
        'assets/icon/app_icon_fg.png');
  });

  test('Play 스토어 아이콘 512 + 그래픽 이미지 1024x500', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const rect = Rect.fromLTWH(0, 0, 512, 512);
    canvas.drawRect(rect, bgPaint(rect));
    drawChart(canvas, const Rect.fromLTWH(91, 106, 330, 310));
    await savePng(recorder.endRecording(), 512, 512,
        'docs/store/icon_512.png');

    final fg = ui.PictureRecorder();
    final c2 = Canvas(fg);
    const banner = Rect.fromLTWH(0, 0, 1024, 500);
    c2.drawRect(banner, bgPaint(banner));
    // 좌측은 스토어 목록에서 앱 이름과 겹치는 영역이라 비워 두고, 우측에 차트.
    drawChart(c2, const Rect.fromLTWH(560, 70, 400, 360));
    drawChart(c2, const Rect.fromLTWH(120, 170, 260, 240));
    await savePng(fg.endRecording(), 1024, 500,
        'docs/store/feature_graphic.png');
  });
}
