/// 시장 섹터. 같은 섹터 종목끼리는 공통 팩터를 공유해 상관을 갖는다.
enum SectorId { tech, bio, manufacturing, finance, energy }

class Sector {
  const Sector({
    required this.id,
    required this.nameKo,
    required this.correlation,
  }) : assert(correlation >= 0 && correlation <= 1);

  final SectorId id;
  final String nameKo;

  /// 섹터 내 종목 간 상관계수 rho (0~1). 공통 팩터 비중으로 사용.
  final double correlation;
}

const List<Sector> kSectors = [
  Sector(id: SectorId.tech, nameKo: 'IT', correlation: 0.45),
  Sector(id: SectorId.bio, nameKo: '바이오', correlation: 0.35),
  Sector(id: SectorId.manufacturing, nameKo: '제조', correlation: 0.40),
  Sector(id: SectorId.finance, nameKo: '금융', correlation: 0.55),
  Sector(id: SectorId.energy, nameKo: '에너지', correlation: 0.50),
];

Sector sectorOf(SectorId id) => kSectors.firstWhere((s) => s.id == id);
