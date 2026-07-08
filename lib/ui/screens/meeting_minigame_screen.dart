import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/colleague.dart';
import '../character/character_avatar.dart';
import '../game_controller.dart';
import 'minigames.dart';

enum _Phase { playing, failed, choosing, joked }

/// 회의실 강제 이동 씬 + 랜덤 미니게임.
/// 성공하면 [옆자리 동료와 장난친다](친밀도) / [몰래 주식 본다](30초 매매 찬스) 선택.
class MeetingMinigameScreen extends StatefulWidget {
  const MeetingMinigameScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<MeetingMinigameScreen> createState() => _MeetingMinigameScreenState();
}

class _MeetingMinigameScreenState extends State<MeetingMinigameScreen> {
  late final MiniGameSpec _game;
  _Phase _phase = _Phase.playing;
  StockTip? _tip;
  Colleague? _from;

  @override
  void initState() {
    super.initState();
    _game = kMiniGames[Random().nextInt(kMiniGames.length)];
  }

  void _onGameResult(bool success) {
    if (_phase != _Phase.playing) return;
    if (!success) {
      widget.controller.session.addPerformance(-2); // 상사한테 걸림
      widget.controller.refresh();
    }
    setState(() => _phase = success ? _Phase.choosing : _Phase.failed);
  }

  /// 딴짓 안 하고 회의에 집중 — 고과 +1.
  void _focus() {
    widget.controller.session.addPerformance(1);
    widget.controller.refresh();
    Navigator.pop(context);
  }

  void _joke() {
    final session = widget.controller.session;
    final from = kColleagues[Random().nextInt(kColleagues.length)];
    session.addRapport(from.id, 4);
    final tip = session.tipFrom(from);
    widget.controller.refresh();
    setState(() {
      _phase = _Phase.joked;
      _from = from;
      _tip = tip;
    });
  }

  void _peek() {
    widget.controller.startPeek(seconds: 30);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회의 중 🗣️'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MeetingRoomArt(
                  playerAvatarId: widget.controller.session.avatarId),
              const SizedBox(height: 12),
              _BreakingNews(controller: widget.controller),
              const SizedBox(height: 16),
              _body(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.playing:
        return Column(
          children: [
            Text(_game.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            Text(_game.howTo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            // 고정 높이 캔버스(스크롤 안전 + 블록부수기 바운드).
            SizedBox(
                height: 300,
                child: _game.build(
                    _onGameResult, widget.controller.session.minigameHandicap)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _focus,
              child: const Text('회의에 집중한다 (고과 +1)',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      case _Phase.failed:
        return _CenteredResult(
          emoji: '😨',
          text: '상사한테 딱 걸렸다! "회의 집중 좀 하지?" (고과 -2)',
          button: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('회의 계속'),
          ),
        );
      case _Phase.choosing:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😏 성공! 뭘 할까?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _joke,
              icon: const Icon(Icons.emoji_emotions),
              label: const Text('옆자리 동료와 장난친다 (친밀도)'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _peek,
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              icon: const Icon(Icons.visibility),
              label: const Text('몰래 주식 본다 (30초 매매)'),
            ),
          ],
        );
      case _Phase.joked:
        final tip = _tip;
        final stock = tip == null
            ? null
            : widget.controller.session.market.stockByCode(tip.stockCode);
        return _CenteredResult(
          emoji: '🤭',
          text: '${_from?.name}와 킥킥 — 친밀도 +4'
              '${tip != null && stock != null ? '\n지나가는 말: ${stock.name} '
                  '${tip.bullish ? '오를 듯 📈' : '빠질 듯 📉'} '
                  '(${tip.reliable ? '정보' : '카더라'})' : ''}',
          button: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('회의 계속'),
          ),
        );
    }
  }
}

class _CenteredResult extends StatelessWidget {
  const _CenteredResult(
      {required this.emoji, required this.text, required this.button});

  final String emoji;
  final String text;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 46)),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        button,
      ],
    );
  }
}

/// 회의실 씬. `assets/images/meeting_room.png`가 있으면 그 이미지를 배경으로 쓰고,
/// 없으면 도형/이모지 플레이스홀더로 폴백한다.
class _MeetingRoomArt extends StatelessWidget {
  const _MeetingRoomArt({required this.playerAvatarId});

  final int playerAvatarId;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/meeting_room.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  const _MeetingRoomPlaceholder(),
            ),
            // 회의실에 앉아 있는 나 (우하단).
            Positioned(
              right: 8,
              bottom: 6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CharacterAvatar(avatarId: playerAvatarId, size: 40),
                  const Text('나',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(blurRadius: 4)])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 이미지 에셋이 없을 때 쓰는 도형+이모지 자리표시자.
// ponytail: assets/images/meeting_room.png 넣으면 이건 안 쓰임.
class _MeetingRoomPlaceholder extends StatelessWidget {
  const _MeetingRoomPlaceholder();

  @override
  Widget build(BuildContext context) {
    final presenter = kColleagues.first;
    final seated = kColleagues.skip(1).toList();
    return Container(
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blueGrey.shade800, Colors.blueGrey.shade900],
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  alignment: Alignment.center,
                  child: const Text('📊  이번 분기 실적 보고',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🗣️', style: TextStyle(fontSize: 15)),
                  CharacterAvatar(avatarId: presenter.avatarId, size: 40),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.brown.shade700.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(30),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                // 플레이어는 _MeetingRoomArt의 공용 오버레이(우하단 '나')로 그려진다.
                children: [
                  for (final c in seated)
                    CharacterAvatar(avatarId: c.avatarId, size: 34),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 회의 중 장에서 큰 이벤트가 진행 중이면 속보 배너. 없으면 아무것도 안 그림.
class _BreakingNews extends StatelessWidget {
  const _BreakingNews({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final breaking = controller.session.market.breakingEvent();
    if (breaking == null) return const SizedBox.shrink();
    final color = breaking.good ? Colors.redAccent : Colors.blueAccent;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Text('🚨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('속보  ${breaking.headline}',
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
