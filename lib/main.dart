import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/save_repository.dart';
import 'ui/game_controller.dart';
import 'ui/screens/character_creation_screen.dart';
import 'ui/screens/colleague_chat_sheet.dart';
import 'ui/screens/colleagues_screen.dart';
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
          const Positioned(bottom: 8, left: 8, right: 8, child: _PeekBanner()),
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
    switch (interaction.kind) {
      case WorkInteractionKind.smoke:
      case WorkInteractionKind.lunch:
      case WorkInteractionKind.dinner:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => ColleagueChatSheet(
            controller: controller,
            colleague: interaction.colleague!,
            flavor: switch (interaction.kind) {
              WorkInteractionKind.lunch => ChatFlavor.lunch,
              WorkInteractionKind.dinner => ChatFlavor.dinner,
              _ => ChatFlavor.smoke,
            },
          ),
        );
      case WorkInteractionKind.meeting:
        await Navigator.of(context).push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => MeetingMinigameScreen(controller: controller),
        ));
    }
    controller.resolveInteraction();
    if (mounted) setState(() => _showing = false);
  }
}

/// 회의 몰래보기(30초 매매 찬스) 카운트다운 배너. 어느 탭에서든 하단에 표시.
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
