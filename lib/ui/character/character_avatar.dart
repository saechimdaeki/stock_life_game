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
      bg: Color(0xFF6FCF97),
      skin: Color(0xFFF4C89E),
      hair: Color(0xFF4E342E),
      hairStyle: 0,
      shirt: Color(0xFFECEFF1)),
  _AvatarStyle(
      bg: Color(0xFF9B8CFF),
      skin: Color(0xFFF1C7A5),
      hair: Color(0xFF212121),
      hairStyle: 1,
      shirt: Color(0xFF37474F)),
  _AvatarStyle(
      bg: Color(0xFFFF9E80),
      skin: Color(0xFFE8B189),
      hair: Color(0xFF7B4A2B),
      hairStyle: 5,
      shirt: Color(0xFFFF7043)),
  _AvatarStyle(
      bg: Color(0xFF4FC3F7),
      skin: Color(0xFFF4C89E),
      hair: Color(0xFFE0C060),
      hairStyle: 2,
      shirt: Color(0xFF5C6BC0)),
  _AvatarStyle(
      bg: Color(0xFF90A4AE),
      skin: Color(0xFFE8B189),
      hair: Color(0xFF9E9E9E),
      hairStyle: 4,
      shirt: Color(0xFF455A64),
      glasses: true),
  _AvatarStyle(
      bg: Color(0xFFF06292),
      skin: Color(0xFFF1C7A5),
      hair: Color(0xFFA65A2E),
      hairStyle: 3,
      shirt: Color(0xFF7E57C2)),
  _AvatarStyle(
      bg: Color(0xFF4DB6AC),
      skin: Color(0xFFF4C89E),
      hair: Color(0xFF3A2A20),
      hairStyle: 0,
      shirt: Color(0xFF26A69A),
      glasses: true),
  _AvatarStyle(
      bg: Color(0xFFFFB74D),
      skin: Color(0xFFE8B189),
      hair: Color(0xFF1A1A1A),
      hairStyle: 1,
      shirt: Color(0xFF8D6E63)),
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

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.s);

  final _AvatarStyle s;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // 배경 (은은한 그라데이션 원반 — 바깥은 ClipOval로 잘림).
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(s.bg, Colors.white, 0.14)!,
            Color.lerp(s.bg, Colors.black, 0.10)!,
          ],
        ).createShader(rect),
    );

    final cx = w / 2;
    final headR = w * 0.24;
    final headC = Offset(cx, h * 0.45);
    final hairPaint = Paint()..color = s.hair;

    // 어깨/상의.
    canvas.drawCircle(Offset(cx, h * 1.02), w * 0.40, Paint()..color = s.shirt);

    // 뒤로 넘어가는 머리(긴머리/포니테일)는 머리보다 먼저.
    if (s.hairStyle == 1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - headR * 1.15, headC.dy - headR * 0.5,
              headR * 2.3, headR * 2.1),
          Radius.circular(headR),
        ),
        hairPaint,
      );
    } else if (s.hairStyle == 3) {
      canvas.drawCircle(
          Offset(cx + headR * 1.05, headC.dy + headR * 0.3), headR * 0.5, hairPaint);
    }

    // 귀 + 머리.
    final skin = Paint()..color = s.skin;
    canvas.drawCircle(Offset(cx - headR, headC.dy), headR * 0.16, skin);
    canvas.drawCircle(Offset(cx + headR, headC.dy), headR * 0.16, skin);
    canvas.drawCircle(headC, headR, skin);

    // 앞머리 캡 (대머리 제외).
    if (s.hairStyle != 4) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, w, headC.dy - headR * 0.12));
      canvas.drawCircle(headC, headR * 1.06, hairPaint);
      canvas.restore();
      if (s.hairStyle == 2) {
        canvas.drawCircle(
            Offset(cx, headC.dy - headR * 1.12), headR * 0.42, hairPaint);
      } else if (s.hairStyle == 5) {
        for (var i = -2; i <= 2; i++) {
          canvas.drawCircle(Offset(cx + i * headR * 0.42, headC.dy - headR * 0.78),
              headR * 0.33, hairPaint);
        }
      }
    }

    // 눈.
    final eyeY = headC.dy + headR * 0.05;
    final eye = Paint()..color = const Color(0xFF37342F);
    canvas.drawCircle(Offset(cx - headR * 0.38, eyeY), headR * 0.09, eye);
    canvas.drawCircle(Offset(cx + headR * 0.38, eyeY), headR * 0.09, eye);

    // 미소.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, eyeY + headR * 0.26), radius: headR * 0.3),
      0.16 * 3.1416,
      0.68 * 3.1416,
      false,
      Paint()
        ..color = const Color(0xFF9A5A46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.09
        ..strokeCap = StrokeCap.round,
    );

    // 안경.
    if (s.glasses) {
      final g = Paint()
        ..color = const Color(0xFF37474F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.06;
      canvas.drawCircle(Offset(cx - headR * 0.38, eyeY), headR * 0.21, g);
      canvas.drawCircle(Offset(cx + headR * 0.38, eyeY), headR * 0.21, g);
      canvas.drawLine(Offset(cx - headR * 0.17, eyeY),
          Offset(cx + headR * 0.17, eyeY), g);
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter old) => old.s != s;
}
