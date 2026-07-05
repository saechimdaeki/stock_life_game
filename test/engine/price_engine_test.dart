import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/engine/engine.dart';

void main() {
  group('PriceEngine', () {
    test('Box-Muller 정규난수의 평균과 표준편차가 표준정규를 따른다', () {
      final engine = PriceEngine(random: Random(42));
      const n = 100000;
      var sum = 0.0;
      var sumSq = 0.0;
      for (var i = 0; i < n; i++) {
        final z = engine.nextGaussian();
        sum += z;
        sumSq += z * z;
      }
      final mean = sum / n;
      final std = sqrt(sumSq / n - mean * mean);

      expect(mean, closeTo(0.0, 0.02));
      expect(std, closeTo(1.0, 0.02));
    });

    test('GBM 틱 수익률의 연환산 드리프트가 입력 파라미터와 일치한다', () {
      // 드리프트 추정의 표준오차는 sigma에 비례하므로
      // 저변동성 파라미터로 노이즈를 줄여 검증한다.
      final engine = PriceEngine(random: Random(7));
      const mu = 0.10;
      const sigma = 0.02;
      const nTicks = 500000;

      var sumLog = 0.0;
      for (var i = 0; i < nTicks; i++) {
        final factor = engine.tickFactor(
          mu: mu,
          sigma: sigma,
          sectorZ: 0,
          rho: 0,
        );
        sumLog += log(factor);
      }

      final ticksPerYear = engine.daysPerYear * engine.ticksPerDay;
      final annualizedDrift = (sumLog / nTicks) * ticksPerYear;

      // 기대 로그 드리프트 = mu - sigma^2/2 ≈ 0.0998
      // 표준오차 = sigma * sqrt(ticksPerYear / n) ≈ 0.0024 -> 허용치 3SE
      expect(annualizedDrift, closeTo(mu - 0.5 * sigma * sigma, 0.008));
    });

    test('GBM 틱 수익률의 연환산 변동성이 입력 파라미터와 일치한다', () {
      final engine = PriceEngine(random: Random(8));
      const sigma = 0.30;
      const nTicks = 500000;

      var sumLog = 0.0;
      var sumLogSq = 0.0;
      for (var i = 0; i < nTicks; i++) {
        final factor = engine.tickFactor(
          mu: 0.10,
          sigma: sigma,
          sectorZ: 0,
          rho: 0,
        );
        final logR = log(factor);
        sumLog += logR;
        sumLogSq += logR * logR;
      }

      final ticksPerYear = engine.daysPerYear * engine.ticksPerDay;
      final meanLog = sumLog / nTicks;
      final varLog = sumLogSq / nTicks - meanLog * meanLog;
      final annualizedVol = sqrt(varLog * ticksPerYear);

      expect(annualizedVol, closeTo(sigma, 0.01));
    });

    test('섹터 공통 팩터를 공유하면 종목 간 수익률 상관이 생긴다', () {
      final engine = PriceEngine(random: Random(11));
      const rho = 0.5;
      const n = 200000;

      var sumA = 0.0, sumB = 0.0, sumAB = 0.0, sumA2 = 0.0, sumB2 = 0.0;
      for (var i = 0; i < n; i++) {
        final sectorZ = engine.nextGaussian();
        final a = log(engine.tickFactor(
            mu: 0, sigma: 0.3, sectorZ: sectorZ, rho: rho));
        final b = log(engine.tickFactor(
            mu: 0, sigma: 0.3, sectorZ: sectorZ, rho: rho));
        sumA += a;
        sumB += b;
        sumAB += a * b;
        sumA2 += a * a;
        sumB2 += b * b;
      }

      final covAB = sumAB / n - (sumA / n) * (sumB / n);
      final varA = sumA2 / n - pow(sumA / n, 2);
      final varB = sumB2 / n - pow(sumB / n, 2);
      final correlation = covAB / sqrt(varA * varB);

      expect(correlation, closeTo(rho, 0.05));
    });

    test('같은 seed면 같은 가격 경로를 만든다 (재현성)', () {
      List<double> run(int seed) {
        final engine = PriceEngine(random: Random(seed));
        final factors = <double>[];
        for (var i = 0; i < 100; i++) {
          factors.add(engine.tickFactor(
              mu: 0.1, sigma: 0.4, sectorZ: 0, rho: 0));
        }
        return factors;
      }

      expect(run(123), equals(run(123)));
    });
  });
}
