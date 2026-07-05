import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine.dart';
import '../format.dart';
import '../game_controller.dart';
import 'stock_detail_screen.dart';

/// 포트폴리오: 자산 요약과 보유 종목 손익.
class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(gameControllerProvider);
    final session = controller.session;
    final portfolio = session.portfolio;
    final prices = session.market.prices;
    final unrealized = portfolio.unrealizedPnl(prices);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('총자산', style: Theme.of(context).textTheme.bodySmall),
                    Text(won(session.totalAssets),
                        style: Theme.of(context).textTheme.headlineSmall),
                    const Divider(height: 20),
                    _SummaryRow(label: '현금', value: won(portfolio.cash)),
                    _SummaryRow(
                        label: '주식 평가액',
                        value: won(portfolio.stockValue(prices))),
                    _SummaryRow(
                      label: '미실현손익',
                      value: signedWon(unrealized),
                      color: unrealized >= 0
                          ? Colors.redAccent
                          : Colors.blueAccent,
                    ),
                    _SummaryRow(
                      label: '실현손익 누계',
                      value: signedWon(portfolio.realizedPnl),
                      color: portfolio.realizedPnl >= 0
                          ? Colors.redAccent
                          : Colors.blueAccent,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('보유 종목', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Expanded(
              child: portfolio.positions.isEmpty
                  ? const Center(
                      child: Text('보유 종목이 없습니다',
                          style: TextStyle(color: Colors.grey)))
                  : ListView(
                      children: [
                        for (final position in portfolio.positions.values)
                          _PositionTile(
                            position: position,
                            currentPrice: prices[position.code],
                            stockName: session.market
                                    .stockByCode(position.code)
                                    ?.name ??
                                position.code,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

class _PositionTile extends StatelessWidget {
  const _PositionTile({
    required this.position,
    required this.currentPrice,
    required this.stockName,
  });

  final Position position;
  final double? currentPrice;
  final String stockName;

  @override
  Widget build(BuildContext context) {
    final price = currentPrice;
    final quantity = position.quantity;
    final totalCost = position.totalCost;
    final value = price == null ? 0.0 : price * quantity;
    final pnl = value - totalCost;
    final rate = totalCost == 0 ? 0.0 : pnl / totalCost;
    final color = pnl > 0
        ? Colors.redAccent
        : (pnl < 0 ? Colors.blueAccent : Colors.grey);

    return ListTile(
      title: Text(stockName),
      subtitle: Text('$quantity주 · 평단 ${won(position.avgPrice)}',
          style: const TextStyle(fontSize: 12)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(won(value),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text('${signedWon(pnl)} (${signedPercent(rate)})',
              style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StockDetailScreen(code: position.code),
        ),
      ),
    );
  }
}
