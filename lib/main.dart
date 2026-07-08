import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/save_repository.dart';
import 'ui/format.dart';
import 'ui/game_controller.dart';
import 'ui/screens/character_creation_screen.dart';
import 'ui/screens/colleague_chat_sheet.dart';
import 'ui/screens/colleagues_screen.dart';
import 'ui/screens/cutscene_screen.dart';
import 'ui/screens/interaction_scenes.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/market_screen.dart';
import 'ui/screens/meeting_minigame_screen.dart';
import 'ui/screens/portfolio_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final saveRepository = SaveRepository();
  await saveRepository.init();
  runApp(
    ProviderScope(
      overrides: [
        saveRepositoryProvider.overrideWithValue(saveRepository),
      ],
      child: const StockLifeApp(),
    ),
  );
}

class StockLifeApp extends StatelessWidget {
  const StockLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '주식 인생',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      // 몰래보기 카운트다운은 Navigator 위에 얹어 어떤 라우트(종목 상세 등)에서도 보인다.
      builder: (context, child) => Stack(
        children: [
          child!,
          // ponytail: bottom 90 고정 — 셸의 NavigationBar를 피하는 눈대중 오프셋.
          const Positioned(bottom: 90, left: 8, right: 8, child: _PeekBanner()),
        ],
      ),
      home: const _Root(),
    );
  }
}

/// 이름 미설정이면 캐릭터 생성 화면, 아니면 메인 셸.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(gameControllerProvider);
    if (controller.session.playerName.isEmpty) {
      return const CharacterCreationScreen();
    }
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    MarketScreen(),
    PortfolioScreen(),
    ColleaguesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _screens),
          const Positioned(top: 8, left: 8, right: 8, child: _GameAlertBanner()),
          const _InteractionHost(),
          const _MorningSceneHost(),
          const _EndingHost(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: '시장'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet), label: '포트폴리오'),
          NavigationDestination(icon: Icon(Icons.groups), label: '동료'),
        ],
      ),
    );
  }
}

/// 근무 인터랙션(회의 미니게임·담배타임)을 어느 탭에서든 모달로 띄운다.
class _InteractionHost extends ConsumerStatefulWidget {
  const _InteractionHost();

  @override
  ConsumerState<_InteractionHost> createState() => _InteractionHostState();
}

class _InteractionHostState extends ConsumerState<_InteractionHost> {
  bool _showing = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(gameControllerProvider);
    final pending = controller.pending;
    if (pending != null && !_showing) {
      _showing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _run(controller, pending));
    }
    return const SizedBox.shrink();
  }

  Future<void> _run(GameController controller, WorkInteraction interaction) async {
    // 진입 컷씬: 옥상/탕비실/식당/회식/회의실로 장면 전환 후 본 인터랙션.
    if (interaction.kind != WorkInteractionKind.insider) {
      await showCutscene(context, introSceneFor(interaction));
      if (!mounted) {
        controller.resolveInteraction();
        return;
      }
    }
    switch (interaction.kind) {
      case WorkInteractionKind.smoke:
      case WorkInteractionKind.lunch:
      case WorkInteractionKind.dinner:
      case WorkInteractionKind.coffee:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => ColleagueChatSheet(
            controller: controller,
            colleague: interaction.colleague!,
            flavor: switch (interaction.kind) {
              WorkInteractionKind.lunch => ChatFlavor.lunch,
              WorkInteractionKind.dinner => ChatFlavor.dinner,
              WorkInteractionKind.coffee => ChatFlavor.coffee,
              _ => ChatFlavor.smoke,
            },
          ),
        );
      case WorkInteractionKind.meeting:
        await Navigator.of(context).push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => MeetingMinigameScreen(controller: controller),
        ));
      case WorkInteractionKind.insider:
        final c = interaction.colleague!;
        final picked = await showCutscene(
          context,
          CutsceneData(
            bgEmoji: '🤫',
            title: '탕비실에서',
            lines: [
              CutsceneLine('${c.name}이(가) 슬쩍 다가와 주위를 둘러본다.'),
              CutsceneLine('...이거 진짜 아무한테도 말하면 안 되는 건데.',
                  speaker: c.name, avatarId: c.avatarId),
              CutsceneLine('내일 아침에 공시 하나 크게 떠. 받을 거야, 말 거야?',
                  speaker: c.name, avatarId: c.avatarId),
              const CutsceneLine('내부자 정보다. 대박 확률이 높지만... 걸리면 벌금에 고과 폭락이다.'),
            ],
            choices: const ['🤝 받는다 (위험 감수)', '🙅 못 들은 걸로 할게'],
          ),
        );
        if (picked == 0) controller.acceptInsiderTip(c);
    }
    controller.resolveInteraction();
    if (mounted) setState(() => _showing = false);
  }
}

/// 아침 컷씬(인사평가·내부자 조사)을 순서대로 띄운다.
class _MorningSceneHost extends ConsumerStatefulWidget {
  const _MorningSceneHost();

  @override
  ConsumerState<_MorningSceneHost> createState() => _MorningSceneHostState();
}

class _MorningSceneHostState extends ConsumerState<_MorningSceneHost> {
  bool _showing = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(gameControllerProvider);
    if (controller.pendingScenes.isNotEmpty && !_showing) {
      _showing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _run(controller));
    }
    return const SizedBox.shrink();
  }

  Future<void> _run(GameController controller) async {
    while (controller.pendingScenes.isNotEmpty && mounted) {
      final scene = controller.pendingScenes.removeAt(0);
      await showCutscene(context, scene);
    }
    if (mounted) setState(() => _showing = false);
  }
}

/// 경제적 자유(총자산 10억) 달성 시 엔딩 다이얼로그를 띄운다. 이후 계속 플레이 가능.
class _EndingHost extends ConsumerStatefulWidget {
  const _EndingHost();

  @override
  ConsumerState<_EndingHost> createState() => _EndingHostState();
}

class _EndingHostState extends ConsumerState<_EndingHost> {
  bool _showing = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(gameControllerProvider);
    if (controller.pendingEnding && !_showing) {
      _showing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(controller));
    }
    return const SizedBox.shrink();
  }

  Future<void> _show(GameController controller) async {
    final session = controller.session;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('👑 경제적 자유!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Day ${session.clock.day}, 총자산 ${won(session.totalAssets)}.'),
            const SizedBox(height: 8),
            const Text('월급쟁이 개미에서 시작해 마침내 10억을 만들었다.\n'
                '이제 상사 눈치도, 몰래보기 30초도 필요 없다.'),
            const SizedBox(height: 8),
            const Text('…물론 내일도 출근은 해야 한다. 계속 달릴까?',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('계속 달린다 🏃'),
          ),
        ],
      ),
    );
    controller.resolveEnding();
    if (mounted) setState(() => _showing = false);
  }
}

/// 회의 몰래보기(30초 매매 찬스) 카운트다운 배너.
/// MaterialApp.builder에서 Navigator 위에 얹혀 어떤 화면·라우트에서도 보인다.
class _PeekBanner extends ConsumerWidget {
  const _PeekBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = ref.watch(gameControllerProvider).peekSecondsLeft;
    if (left <= 0) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(10),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text('🔓 몰래보기 — 지금 매매! ${left}s',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

/// 매매 구간 진입 등 이벤트를 어느 탭에서든 좌상단에 잠깐 띄운다.
class _GameAlertBanner extends ConsumerStatefulWidget {
  const _GameAlertBanner();

  @override
  ConsumerState<_GameAlertBanner> createState() => _GameAlertBannerState();
}

class _GameAlertBannerState extends ConsumerState<_GameAlertBanner> {
  int _shownSeq = 0;
  String? _message;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(gameControllerProvider);
    if (controller.alertSeq != _shownSeq) {
      _shownSeq = controller.alertSeq;
      _message = controller.alert;
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _message = null);
      });
    }
    final message = _message;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: message == null
          ? const SizedBox.shrink()
          : Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.teal.shade700,
                borderRadius: BorderRadius.circular(10),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Text(
                    message,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
              ),
            ),
    );
  }
}
