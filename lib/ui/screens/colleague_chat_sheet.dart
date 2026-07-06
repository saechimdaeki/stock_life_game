import 'package:flutter/material.dart';

import '../../data/colleague.dart';
import '../character/character_avatar.dart';
import '../game_controller.dart';

/// 대화 상황. 문구·보상 맥락만 다르고 구조는 같다.
enum ChatFlavor { smoke, lunch, dinner, coffee }

/// 동료와의 짧은 대화(담배타임·점심·회식). 함께하면 친밀도가 오르고 정보를 얻는다.
/// (닫기/무시하면 보상 없음.)
class ColleagueChatSheet extends StatefulWidget {
  const ColleagueChatSheet({
    super.key,
    required this.controller,
    required this.colleague,
    required this.flavor,
  });

  final GameController controller;
  final Colleague colleague;
  final ChatFlavor flavor;

  @override
  State<ColleagueChatSheet> createState() => _ColleagueChatSheetState();
}

class _ColleagueChatSheetState extends State<ColleagueChatSheet> {
  StockTip? _tip;
  bool _joined = false;

  String get _title => switch (widget.flavor) {
        ChatFlavor.smoke => '${widget.colleague.name}와 담배 한 대 🚬',
        ChatFlavor.lunch => '${widget.colleague.name}와 점심 식사 🍚',
        ChatFlavor.dinner => '${widget.colleague.name}와 회식 🍻',
        ChatFlavor.coffee => '${widget.colleague.name}와 커피 한 잔 ☕',
      };

  String get _prompt => switch (widget.flavor) {
        ChatFlavor.smoke => '「${widget.colleague.name}」가 담배 피우러 가자는데?',
        ChatFlavor.lunch => '「${widget.colleague.name}」와 점심 같이 먹을까?',
        ChatFlavor.dinner => '「${widget.colleague.name}」가 회식 가자는데?',
        ChatFlavor.coffee => '「${widget.colleague.name}」가 커피 마시러 가자는데?',
      };

  String get _acceptLabel => switch (widget.flavor) {
        ChatFlavor.smoke => '같이 간다',
        ChatFlavor.lunch => '같이 먹는다',
        ChatFlavor.dinner => '콜! 회식 간다',
        ChatFlavor.coffee => '커피 콜 ☕',
      };

  String get _declineLabel => switch (widget.flavor) {
        ChatFlavor.smoke => '자리 지킨다',
        ChatFlavor.lunch => '혼자 먹는다',
        ChatFlavor.dinner => '다음에요',
        ChatFlavor.coffee => '일이 많아서...',
      };

  String get _lead => switch (widget.flavor) {
        ChatFlavor.smoke => '담배 피우며 들은 소문',
        ChatFlavor.lunch => '밥 먹으며 들은 얘기',
        ChatFlavor.dinner => '회식 자리에서 들은 얘기',
        ChatFlavor.coffee => '커피 마시며 들은 수다',
      };

  String get _noTipText => switch (widget.flavor) {
        ChatFlavor.smoke => '"시장이 조용하네~" 담배만 태웠다.',
        ChatFlavor.lunch => '"요즘 살 만한 게 없네~" 밥만 먹고 왔다.',
        ChatFlavor.dinner => '"오늘은 그냥 마시자~" 별 얘기 없이 취했다.',
        ChatFlavor.coffee => '"주말에 뭐 해?" 수다만 떨다 왔다.',
      };

  /// 친밀도 보상. 회식은 시간·컨디션 대가가 커서 조금 더 준다.
  int get _gain => widget.flavor == ChatFlavor.dinner ? 6 : 3;

  void _join() {
    final session = widget.controller.session;
    session.addRapport(widget.colleague.id, _gain);
    final tip = session.tipFrom(widget.colleague);
    // 회식은 취하고 시간이 훌쩍 지난다(그 대가로 미장 차트가 춤춘다).
    if (widget.flavor == ChatFlavor.dinner) widget.controller.finishDinner();
    widget.controller.refresh();
    setState(() {
      _joined = true;
      _tip = tip;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colleague;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CharacterAvatar(avatarId: c.avatarId, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_joined ? _title : _prompt,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_joined)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(_declineLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _join,
                      child: Text(_acceptLabel),
                    ),
                  ),
                ],
              )
            else ...[
              _resultBody(),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('자리로 복귀'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultBody() {
    final tip = _tip;
    final stock =
        tip == null ? null : widget.controller.session.market.stockByCode(tip.stockCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tip == null)
          Text(_noTipText, style: const TextStyle(color: Colors.grey))
        else ...[
          Text('친밀도 +$_gain',
              style: const TextStyle(color: Colors.teal, fontSize: 13)),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(text: '$_lead: '),
                TextSpan(
                  text: '${stock?.name ?? tip.stockCode} '
                      '${tip.bullish ? '오를 것 같다' : '빠질 것 같다'}',
                  style: TextStyle(
                      color: tip.bullish ? Colors.redAccent : Colors.blueAccent,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(tip.reliable ? '💡 꽤 믿을 만한 정보' : '💬 카더라 통신 (가끔 틀림)',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
        if (widget.flavor == ChatFlavor.dinner) ...[
          const SizedBox(height: 10),
          Text('🍺 얼큰하게 취했다 — 시간이 훌쩍 지났고, 오늘 밤 미장 차트가 춤춘다...',
              style: TextStyle(
                  color: Colors.orange.shade300,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}
