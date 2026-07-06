import 'dart:math';

/// GBM(기하 브라운 운동) 기반 틱 가격 생성기.
///
/// 틱당 로그수익률:
///   dlnS = (mu - sigma^2/2) * dt + sigma * sqrt(dt) * Z
///   Z = sqrt(rho) * Z_sector + sqrt(1-rho) * Z_own
/// 섹터 공통 팩터 Z_sector를 같은 섹터 종목이 공유해 상관을 만든다.
class PriceEngine {
  PriceEngine({
    required this._random,
    this.ticksPerDay = 26,
    this.daysPerYear = 240,
    this.microSteps = 1,
  }) : assert(microSteps >= 1);

  final Random _random;

  /// 거래소 세션당 틱 수 (국장·미장 모두 6.5시간 = 15분 x 26틱).
  final int ticksPerDay;

  /// 게임 내 1년 = 240 거래일 기준으로 연환산 파라미터를 환산.
  final int daysPerYear;

  /// 한 클럭틱(15분)을 몇 번으로 잘게 나눠 그릴지. 차트를 부드럽게 이어준다.
  /// 클럭틱당 총 변동 분포는 동일하게 유지된다(각 마이크로 스텝 dt = dt/microSteps).
  final int microSteps;

  double get dt => 1.0 / (daysPerYear * ticksPerDay);

  double? _spareGaussian;

  /// 표준정규 난수 (Box-Muller, 짝으로 생성해 하나는 캐시).
  double nextGaussian() {
    final spare = _spareGaussian;
    if (spare != null) {
      _spareGaussian = null;
      return spare;
    }
    double u1;
    do {
      u1 = _random.nextDouble();
    } while (u1 <= 1e-12);
    final u2 = _random.nextDouble();
    final r = sqrt(-2.0 * log(u1));
    _spareGaussian = r * sin(2.0 * pi * u2);
    return r * cos(2.0 * pi * u2);
  }

  /// 한 틱의 가격 배율을 반환한다 (newPrice = price * factor).
  ///
  /// [mu], [sigma]는 연환산 유효 파라미터(이벤트 효과 반영 후),
  /// [sectorZ]는 이번 틱에 섹터가 공유하는 표준정규 난수,
  /// [rho]는 섹터 상관계수.
  double tickFactor({
    required double mu,
    required double sigma,
    required double sectorZ,
    required double rho,
    int steps = 1,
  }) {
    final stepDt = dt / steps;
    final z = sqrt(rho) * sectorZ + sqrt(1.0 - rho) * nextGaussian();
    final logReturn =
        (mu - 0.5 * sigma * sigma) * stepDt + sigma * sqrt(stepDt) * z;
    return exp(logReturn);
  }
}
