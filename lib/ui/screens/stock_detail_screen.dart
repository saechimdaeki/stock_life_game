import 'dart:math';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/colleague.dart';
import '../../data/game_session.dart';
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
              _TipLine(session: session, code: code),
              if (session.drunk || session.tooTired)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      session.drunk
                          ? '🍺 취함 — 차트가 춤춘다. 정신 차리고 매매!'
                          : '😵 과로 — 눈이 침침해서 차트가 흔들려 보인다',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade300,
                          fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: _DrunkEffect(
                  drunk: session.drunk || session.tooTired,
                  child: _PriceChart(stock: stock),
                ),
              ),
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

/// 동료에게 얻은 정보가 이 종목에 있으면 한 줄 표시.
class _TipLine extends StatelessWidget {
  const _TipLine({required this.session, required this.code});

  final GameSession session;
  final String code;

  @override
  Widget build(BuildContext context) {
    StockTip? tip;
    for (final t in session.todayTips) {
      if (t.stockCode == code) tip = t;
    }
    if (tip == null) return const SizedBox.shrink();
    final color = tip.bullish ? Colors.redAccent : Colors.blueAccent;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '💡 「${tip.fromName}」 ${tip.reliable ? '정보' : '소문'}: '
        '${tip.bullish ? '상승 우세' : '하락 우세'}',
        style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
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

/// 취했을 때 차트가 춤추듯 흔들리고 흐릿하게 보이는 효과. 취하지 않으면 그대로.
class _DrunkEffect extends StatefulWidget {
  const _DrunkEffect({required this.drunk, required this.child});

  final bool drunk;
  final Widget child;

  @override
  State<_DrunkEffect> createState() => _DrunkEffectState();
}

class _DrunkEffectState extends State<_DrunkEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
    if (widget.drunk) _ac.repeat();
  }

  @override
  void didUpdateWidget(_DrunkEffect old) {
    super.didUpdateWidget(old);
    if (widget.drunk && !_ac.isAnimating) {
      _ac.repeat();
    } else if (!widget.drunk && _ac.isAnimating) {
      _ac.stop();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.drunk) return widget.child;
    return AnimatedBuilder(
      animation: _ac,
      builder: (context, child) {
        final t = _ac.value * 2 * pi;
        final dx = sin(t) * 9;
        final dy = cos(t * 1.3) * 5;
        final rot = sin(t * 0.8) * 0.05;
        final scale = 1 + sin(t * 1.7) * 0.02;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translateByDouble(dx, dy, 0, 1)
            ..rotateZ(rot)
            ..scaleByDouble(scale, scale, 1, 1),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 차트 기간. 당일=오늘 장중 틱, 나머지=일봉(하루 1캔들) N개.
enum _ChartRange { today, week, month, all }

extension on _ChartRange {
  String get label => switch (this) {
        _ChartRange.today => '당일',
        _ChartRange.week => '1주',
        _ChartRange.month => '1달',
        _ChartRange.all => '전체',
      };

  /// 일봉 뷰에서 보여줄 캔들 수 (당일은 무의미).
  int get dailyCount => switch (this) {
        _ChartRange.today => 0,
        _ChartRange.week => 7,
        _ChartRange.month => 30,
        _ChartRange.all => 1 << 30,
      };
}

class _PriceChart extends StatefulWidget {
  const _PriceChart({required this.stock});

  final Stock stock;

  @override
  State<_PriceChart> createState() => _PriceChartState();
}

class _PriceChartState extends State<_PriceChart> {
  late _ChartRange _range;

  @override
  void initState() {
    super.initState();
    // 일봉이 쌓였으면 1주 뷰로, 아직이면 당일 뷰로 시작.
    _range = widget.stock.candleHistory.length >= 2
        ? _ChartRange.week
        : _ChartRange.today;
  }

  /// 오늘 장중 틱을 캔들로 그룹핑 (당일 뷰).
  /// 그룹당 최소 3틱을 묶어 고가·저가 꼬리(심지)가 생기게 한다.
  static List<Candle> _intradayCandles(List<double> ticks) {
    if (ticks.length < 3) return const [];
    final groupSize = (ticks.length / 16).ceil().clamp(3, ticks.length).toInt();
    final result = <Candle>[];
    for (var i = 0; i < ticks.length; i += groupSize) {
      final end = (i + groupSize).clamp(0, ticks.length).toInt();
      final slice = ticks.sublist(i, end);
      var hi = slice.first, lo = slice.first;
      for (final p in slice) {
        if (p > hi) hi = p;
        if (p < lo) lo = p;
      }
      result.add(Candle(
          open: slice.first, high: hi, low: lo, close: slice.last));
    }
    return result;
  }

  List<Candle> _candles() {
    final stock = widget.stock;
    if (_range == _ChartRange.today) {
      return _intradayCandles(stock.tickHistory);
    }
    final daily = [
      ...stock.candleHistory,
      if (stock.formingCandle != null) stock.formingCandle!,
    ];
    final n = _range.dailyCount;
    return daily.length > n ? daily.sublist(daily.length - n) : daily;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<_ChartRange>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
            segments: [
              for (final r in _ChartRange.values)
                ButtonSegment(value: r, label: Text(r.label)),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildChart()),
      ],
    );
  }

  Widget _buildChart() {
    final candles = _candles();
    if (candles.length < 2) {
      return Center(
        child: Text(
          _range == _ChartRange.today ? '장중 데이터 수집 중...' : '아직 일봉이 부족합니다',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    // 각 봉의 시가를 직전 봉 종가에 맞춰 이어붙여 끊김 없이 보이게 한다.
    final spots = <CandlestickSpot>[];
    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      final open = i == 0 ? c.open : candles[i - 1].close;
      spots.add(CandlestickSpot(
        x: i.toDouble(),
        open: open,
        high: c.high > open ? c.high : open,
        low: c.low < open ? c.low : open,
        close: c.close,
      ));
    }
    // 위아래 5% 여백을 둬서 꼬리가 잘리지 않게 한다.
    var hi = spots.first.high, lo = spots.first.low;
    for (final s in spots) {
      if (s.high > hi) hi = s.high;
      if (s.low < lo) lo = s.low;
    }
    final pad = (hi - lo) * 0.05 + 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 몸통 폭을 실제 슬롯 폭에 비례시켜 화면을 꽉 채운다 (띄엄띄엄 방지).
        final slot = constraints.maxWidth / candles.length;
        final bodyWidth = (slot * 0.62).clamp(2.0, 40.0);
        CandlestickStyle styleFor(CandlestickSpot spot, int _) {
          final color = spot.isUp ? Colors.redAccent : Colors.blueAccent;
          return CandlestickStyle(
            lineColor: color,
            lineWidth: 1.5,
            bodyStrokeColor: color,
            bodyStrokeWidth: 1,
            bodyFillColor: color,
            bodyWidth: bodyWidth,
            bodyRadius: 1,
          );
        }

        return CandlestickChart(
          CandlestickChartData(
            candlestickSpots: spots,
            minY: lo - pad,
            maxY: hi + pad,
            candlestickPainter:
                DefaultCandlestickPainter(candlestickStyleProvider: styleFor),
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            candlestickTouchData: CandlestickTouchData(enabled: false),
          ),
        );
      },
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
      final unitCost = session.market.priceKrwOf(widget.stock) *
          (1 + session.portfolio.feeRate);
      return unitCost <= 0 ? 0 : budget ~/ unitCost;
    }
    return session.portfolio.positionOf(widget.stock.code)?.quantity ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final market = widget.controller.session.market;
    final total = market.priceKrwOf(widget.stock) * quantity;
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
              '${widget.stock.exchangeId == ExchangeId.us ? ' (환율 ${market.usdKrw.round()}원)' : ''}'),
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
