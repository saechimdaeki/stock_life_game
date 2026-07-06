import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/colleague.dart';
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
    final tipByCode = {for (final t in session.todayTips) t.stockCode: t};

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
                      tipByCode: tipByCode,
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

/// 동료에게 얻은 정보 배지 (상승=빨강/하락=파랑, 소문은 옅게).
class _TipBadge extends StatelessWidget {
  const _TipBadge({required this.tip});

  final StockTip tip;

  @override
  Widget build(BuildContext context) {
    final base = tip.bullish ? Colors.redAccent : Colors.blueAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: base.withValues(alpha: tip.reliable ? 0.35 : 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '💡${tip.bullish ? '▲' : '▼'}${tip.reliable ? '' : '?'}',
        style: TextStyle(fontSize: 11, color: base),
      ),
    );
  }
}

class _StockList extends StatelessWidget {
  const _StockList({required this.stocks, required this.tipByCode});

  final List<Stock> stocks;
  final Map<String, StockTip> tipByCode;

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
        final tip = tipByCode[stock.code];
        return ListTile(
          title: Row(
            children: [
              Flexible(child: Text(stock.name)),
              if (tip != null) ...[
                const SizedBox(width: 6),
                _TipBadge(tip: tip),
              ],
            ],
          ),
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
