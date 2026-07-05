import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine.dart';
import '../format.dart';
import '../game_controller.dart';
import 'stock_detail_screen.dart';

/// 시장: 국장/미장 탭과 종목 리스트.
class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(gameControllerProvider);
    final session = controller.session;

    return DefaultTabController(
      length: kExchanges.length,
      child: SafeArea(
        child: Column(
          children: [
            TabBar(
              tabs: [
                for (final exchange in kExchanges)
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(exchange.nameKo),
                        const SizedBox(width: 6),
                        _OpenBadge(
                          isOpen: exchange
                              .isOpenAt(session.clock.minuteOfDay),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final exchange in kExchanges)
                    _StockList(
                      stocks: session.market.listedOn(exchange.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  const _OpenBadge({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.shade700 : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOpen ? '개장' : '폐장',
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
    );
  }
}

class _StockList extends StatelessWidget {
  const _StockList({required this.stocks});

  final List<Stock> stocks;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: stocks.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final stock = stocks[index];
        final rate = stock.todayChangeRate;
        final color = rate > 0
            ? Colors.redAccent
            : (rate < 0 ? Colors.blueAccent : Colors.grey);
        return ListTile(
          title: Text(stock.name),
          subtitle: Text(sectorOf(stock.sectorId).nameKo,
              style: const TextStyle(fontSize: 12)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(stockPrice(stock),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              Text(signedPercent(rate),
                  style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StockDetailScreen(code: stock.code),
            ),
          ),
        );
      },
    );
  }
}
