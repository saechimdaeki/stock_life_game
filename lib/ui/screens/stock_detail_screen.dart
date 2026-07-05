import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine.dart';
import '../format.dart';
import '../game_controller.dart';

/// 종목 상세: 차트 + 매수/매도.
class StockDetailScreen extends ConsumerWidget {
  const StockDetailScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(gameControllerProvider);
    final session = controller.session;
    final stock = session.market.stockByCode(code);
    if (stock == null) {
      return const Scaffold(body: Center(child: Text('종목을 찾을 수 없습니다')));
    }

    final tradable =
        session.market.isTradableAt(stock, session.clock.minuteOfDay);
    final position = session.portfolio.positionOf(code);
    final rate = stock.todayChangeRate;
    final rateColor = rate > 0
        ? Colors.redAccent
        : (rate < 0 ? Colors.blueAccent : Colors.grey);

    return Scaffold(
      appBar: AppBar(
        title: Text('${stock.name} (${stock.exchange.nameKo})'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(stockPrice(stock),
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(signedPercent(rate),
                        style: TextStyle(color: rateColor)),
                  ),
                  const Spacer(),
                  _OpenLabel(tradable: tradable),
                ],
              ),
              Text(
                sectorOf(stock.sectorId).nameKo +
                    (position != null
                        ? ' · 보유 ${position.quantity}주 (평단 ${won(position.avgPrice)})'
                        : ''),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Expanded(child: _PriceChart(stock: stock)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent),
                      onPressed: tradable
                          ? () => _showTradeSheet(context, controller, stock,
                              isBuy: true)
                          : null,
                      child: const Text('매수'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.blueAccent),
                      onPressed: tradable && position != null
                          ? () => _showTradeSheet(context, controller, stock,
                              isBuy: false)
                          : null,
                      child: const Text('매도'),
                    ),
                  ),
                ],
              ),
              if (!tradable)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('장이 열려 있지 않습니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTradeSheet(
    BuildContext context,
    GameController controller,
    Stock stock, {
    required bool isBuy,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _TradeSheet(
            controller: controller, stock: stock, isBuy: isBuy),
      ),
    );
  }
}

class _OpenLabel extends StatelessWidget {
  const _OpenLabel({required this.tradable});

  final bool tradable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tradable ? Colors.green.shade700 : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(tradable ? '거래 가능' : '장 마감',
          style: const TextStyle(fontSize: 11, color: Colors.white)),
    );
  }
}

class _PriceChart extends StatelessWidget {
  const _PriceChart({required this.stock});

  final Stock stock;

  @override
  Widget build(BuildContext context) {
    // 일봉 종가 + 오늘 장중 틱을 이어 붙인 라인 차트
    final values = [...stock.closeHistory, ...stock.tickHistory];
    if (values.length < 2) {
      return const Center(
          child: Text('차트 데이터 수집 중...',
              style: TextStyle(color: Colors.grey)));
    }
    final spots = [
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), values[i]),
    ];
    final isUp = values.last >= values.first;
    final lineColor = isUp ? Colors.redAccent : Colors.blueAccent;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            dotData: const FlDotData(show: false),
            color: lineColor,
            barWidth: 2,
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeSheet extends StatefulWidget {
  const _TradeSheet({
    required this.controller,
    required this.stock,
    required this.isBuy,
  });

  final GameController controller;
  final Stock stock;
  final bool isBuy;

  @override
  State<_TradeSheet> createState() => _TradeSheetState();
}

class _TradeSheetState extends State<_TradeSheet> {
  int quantity = 1;

  int get maxQuantity {
    final session = widget.controller.session;
    if (widget.isBuy) {
      final budget = session.portfolio.cash;
      final unitCost =
          widget.stock.priceKrw * (1 + session.portfolio.feeRate);
      return unitCost <= 0 ? 0 : budget ~/ unitCost;
    }
    return session.portfolio.positionOf(widget.stock.code)?.quantity ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.stock.priceKrw * quantity;
    final label = widget.isBuy ? '매수' : '매도';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.stock.name} $label',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('현재가 ${stockPrice(widget.stock)}'
              '${widget.stock.exchangeId == ExchangeId.us ? ' (환율 ${kUsdKrw.round()}원)' : ''}'),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                onPressed: quantity > 1
                    ? () => setState(() => quantity--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Expanded(
                child: Text('$quantity주',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                onPressed: quantity < maxQuantity
                    ? () => setState(() => quantity++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
              TextButton(
                onPressed: maxQuantity > 0
                    ? () => setState(() => quantity = maxQuantity)
                    : null,
                child: const Text('최대'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('주문 금액: ${won(total)}', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  widget.isBuy ? Colors.redAccent : Colors.blueAccent,
            ),
            onPressed: maxQuantity > 0 ? _execute : null,
            child: Text('$quantity주 $label'),
          ),
        ],
      ),
    );
  }

  void _execute() {
    final session = widget.controller.session;
    final result = widget.isBuy
        ? session.buy(widget.stock, quantity)
        : session.sell(widget.stock, quantity);
    widget.controller.refresh();
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.isSuccess
            ? '${widget.stock.name} $quantity주 ${widget.isBuy ? '매수' : '매도'} 체결'
            : result.message!),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
