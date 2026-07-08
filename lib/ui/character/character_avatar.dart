import 'dart:math';

import 'package:flutter/material.dart';

/// 아바타 스타일 프리셋. 코드로 그리는 플랫 캐릭터(피부·헤어·옷·안경).
/// `assets/images/avatar_<id>.png`를 넣으면 그 이미지로 대체된다.
class _AvatarStyle {
  const _AvatarStyle({
    required this.bg,
    required this.skin,
    required this.hair,
    required this.hairStyle, // 0 단발 1 긴머리 2 번(올림) 3 포니테일 4 대머리 5 곱슬
    required this.shirt,
    this.glasses = false,
  });

  final Color bg;
  final Color skin;
  final Color hair;
  final int hairStyle;
  final Color shirt;
  final bool glasses;
}

const List<_AvatarStyle> _styles = [
  _AvatarStyle(
      bg: Color(0xFFA8DCC5),
      skin: Color(0xFFFFD9B8),
      hair: Color(0xFF4E342E),
      hairStyle: 0,
      shirt: Color(0xFFF5F0E8)),
  _AvatarStyle(
      bg: Color(0xFFB9AEF4),
      skin: Color(0xFFF9CFA8),
      hair: Color(0xFF2B2B2B),
      hairStyle: 1,
      shirt: Color(0xFF44546A)),
  _AvatarStyle(
      bg: Color(0xFFF9BFA4),
      skin: Color(0xFFEBB58C),
      hair: Color(0xFF7B4A2B),
      hairStyle: 5,
      shirt: Color(0xFFEF7A54)),
  _AvatarStyle(
      bg: Color(0xFF9BD0F5),
      skin: Color(0xFFFFD9B8),
      hair: Color(0xFFE7C368),
      hairStyle: 2,
      shirt: Color(0xFF6474C8)),
  _AvatarStyle(
      bg: Color(0xFFB8C4CE),
      skin: Color(0xFFEBB58C),
      hair: Color(0xFFB0B4B8),
      hairStyle: 4,
      shirt: Color(0xFF4C5A66),
      glasses: true),
  _AvatarStyle(
      bg: Color(0xFFF6ACC8),
      skin: Color(0xFFF9CFA8),
      hair: Color(0xFFB4653A),
      hairStyle: 3,
      shirt: Color(0xFF8A6DC8)),
  _AvatarStyle(
      bg: Color(0xFF93D8CE),
      skin: Color(0xFFFFD9B8),
      hair: Color(0xFF3A2A20),
      hairStyle: 0,
      shirt: Color(0xFF2FA79A),
      glasses: true),
  _AvatarStyle(
      bg: Color(0xFFF8CE95),
      skin: Color(0xFFEBB58C),
      hair: Color(0xFF1F1F1F),
      hairStyle: 1,
      shirt: Color(0xFF9A7B68)),
];

int get avatarCount => _styles.length;

/// 원형 아바타. 에셋 이미지가 있으면 사용, 없으면 벡터로 그린다.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.avatarId,
    this.size = 48,
    this.selected = false,
  });

  final int avatarId;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final style = _styles[avatarId % _styles.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: selected ? Colors.teal : Colors.transparent, width: 3),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/avatar_$avatarId.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => CustomPaint(
            painter: _AvatarPainter(style),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// 둥근 실루엣 + 큰 눈 + 볼터치의 플랫 치비 스타일.
class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.s);

  final _AvatarStyle s;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // 파스텔 방사형 배경.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 1.2,
          colors: [Color.lerp(s.bg, Colors.white, 0.35)!, s.bg],
        ).createShader(rect),
    );

    final cx = w / 2;
    final headR = w * 0.27;
    final headC = Offset(cx, h * 0.45);
    final hairPaint = Paint()..color = s.hair;
    final skinPaint = Paint()..color = s.skin;

    // 목.
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(cx, headC.dy + headR * 1.05),
          width: headR * 0.52,
          height: headR * 0.6),
      skinPaint,
    );

    // 어깨/상의 (둥근 사각) + 옅은 칼라 라인.
    final shoulder = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, h * 1.12), width: w * 0.82, height: h * 0.72),
      Radius.circular(w * 0.26),
    );
    canvas.drawRRect(shoulder, Paint()..color = s.shirt);
    canvas.drawRRect(
      shoulder.deflate(headR * 0.10),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.07,
    );

    // 뒤로 넘어가는 머리(긴머리/포니테일)는 머리보다 먼저.
    if (s.hairStyle == 1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, headC.dy + headR * 0.62),
              width: headR * 2.35,
              height: headR * 2.5),
          Radius.circular(headR * 0.8),
        ),
        hairPaint,
      );
    } else if (s.hairStyle == 3) {
      canvas.drawCircle(
          Offset(cx + headR * 1.05, headC.dy - headR * 0.3), headR * 0.40,
          hairPaint);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + headR * 1.18, headC.dy + headR * 0.55),
            width: headR * 0.55,
            height: headR * 1.2),
        hairPaint,
      );
    }

    // 귀.
    canvas.drawCircle(Offset(cx - headR, headC.dy + headR * 0.1),
        headR * 0.18, skinPaint);
    canvas.drawCircle(Offset(cx + headR, headC.dy + headR * 0.1),
        headR * 0.18, skinPaint);

    // 머리 위 헤어 (얼굴 밖으로 보이는 부분: 헬멧 림/번/곱슬 퍼프/대머리 옆머리).
    switch (s.hairStyle) {
      case 4: // 대머리: 양옆 남은 머리.
        canvas.drawCircle(Offset(cx - headR * 0.98, headC.dy - headR * 0.2),
            headR * 0.24, hairPaint);
        canvas.drawCircle(Offset(cx + headR * 0.98, headC.dy - headR * 0.2),
            headR * 0.24, hairPaint);
      case 5: // 곱슬: 정수리를 따라 퍼프.
        for (var i = 0; i < 5; i++) {
          final a = pi + pi * (i + 0.5) / 5; // 좌→우 위쪽 반원
          canvas.drawCircle(
            headC + Offset(cos(a), sin(a)) * headR * 1.0,
            headR * 0.36,
            hairPaint,
          );
        }
      default: // 헬멧 림.
        canvas.drawCircle(
            Offset(cx, headC.dy - headR * 0.18), headR * 1.05, hairPaint);
        if (s.hairStyle == 2) {
          canvas.drawCircle(
              Offset(cx, headC.dy - headR * 1.28), headR * 0.42, hairPaint);
        }
    }

    // 얼굴.
    canvas.drawCircle(headC, headR, skinPaint);

    // 앞머리: 얼굴 안쪽에 스캘럽(둥근 갈래) 3개 (대머리 제외).
    if (s.hairStyle != 4) {
      canvas.save();
      canvas.clipPath(
          Path()..addOval(Rect.fromCircle(center: headC, radius: headR)));
      canvas.drawCircle(
          Offset(cx, headC.dy - headR * 0.66), headR * 0.55, hairPaint);
      canvas.drawCircle(Offset(cx - headR * 0.60, headC.dy - headR * 0.55),
          headR * 0.48, hairPaint);
      canvas.drawCircle(Offset(cx + headR * 0.60, headC.dy - headR * 0.55),
          headR * 0.48, hairPaint);
      canvas.restore();
      // 윤기 하이라이트.
      canvas.drawArc(
        Rect.fromCircle(
            center: Offset(cx, headC.dy - headR * 0.18), radius: headR * 0.82),
        -2.5,
        0.6,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = headR * 0.10
          ..strokeCap = StrokeCap.round,
      );
    }

    // 얼굴 옆 잔머리(단발/긴머리/포니테일).
    if (s.hairStyle == 0 || s.hairStyle == 1 || s.hairStyle == 3) {
      final lockH = headR * (s.hairStyle == 1 ? 1.25 : 0.9);
      const lockW = 0.24;
      for (final sign in [-1, 1]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
                cx + sign * headR * 1.02 - (sign > 0 ? headR * lockW : 0),
                headC.dy - headR * 0.5,
                headR * lockW,
                lockH),
            Radius.circular(headR * 0.12),
          ),
          hairPaint,
        );
      }
    }

    // 눈: 큰 타원 + 흰 반짝임.
    final eyeY = headC.dy + headR * 0.18;
    final eyePaint = Paint()..color = const Color(0xFF3A342E);
    for (final sign in [-1, 1]) {
      final c = Offset(cx + sign * headR * 0.36, eyeY);
      canvas.drawOval(
          Rect.fromCenter(
              center: c, width: headR * 0.20, height: headR * 0.28),
          eyePaint);
      canvas.drawCircle(c + Offset(-headR * 0.03, -headR * 0.06),
          headR * 0.05, Paint()..color = Colors.white);
    }

    // 볼터치.
    final blush = Paint()
      ..color = const Color(0xFFFF8FA3).withValues(alpha: 0.45);
    for (final sign in [-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + sign * headR * 0.62, eyeY + headR * 0.24),
            width: headR * 0.30,
            height: headR * 0.18),
        blush,
      );
    }

    // 입: 방긋 벌린 반원.
    final mouth = Path()
      ..addArc(
          Rect.fromCircle(
              center: Offset(cx, eyeY + headR * 0.34), radius: headR * 0.17),
          0,
          pi)
      ..close();
    canvas.drawPath(mouth, Paint()..color = const Color(0xFF8C4A3C));

    // 안경.
    if (s.glasses) {
      final g = Paint()
        ..color = const Color(0xFF37474F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.07;
      for (final sign in [-1, 1]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx + sign * headR * 0.36, eyeY),
                width: headR * 0.48,
                height: headR * 0.42),
            Radius.circular(headR * 0.13),
          ),
          g,
        );
      }
      canvas.drawLine(Offset(cx - headR * 0.12, eyeY - headR * 0.05),
          Offset(cx + headR * 0.12, eyeY - headR * 0.05), g);
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter old) => old.s != s;
}
