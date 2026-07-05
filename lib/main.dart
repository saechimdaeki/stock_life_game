import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/save_repository.dart';
import 'ui/game_controller.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/market_screen.dart';
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
      home: const MainShell(),
    );
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: '시장'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet), label: '포트폴리오'),
        ],
      ),
    );
  }
}
