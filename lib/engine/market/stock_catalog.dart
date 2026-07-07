import 'exchange.dart';
import 'sector.dart';
import 'stock.dart';

/// MVP 초기 종목: 국장 15개(섹터당 3개) + 미장 10개. 전부 가상 회사.
/// mu/sigma는 연환산 - 우량주는 낮은 변동성, 테마주는 높은 변동성.
List<Stock> createInitialStocks() => [
      // IT
      Stock(code: '110001', name: '한빛전자', sectorId: SectorId.tech, baseMu: 0.08, baseSigma: 0.25, initialPrice: 68000),
      Stock(code: '110002', name: '코스모소프트', sectorId: SectorId.tech, baseMu: 0.10, baseSigma: 0.45, initialPrice: 32000),
      Stock(code: '110003', name: '넥스트AI', sectorId: SectorId.tech, baseMu: 0.12, baseSigma: 0.70, initialPrice: 15400),
      // 바이오
      Stock(code: '220001', name: '대성바이오', sectorId: SectorId.bio, baseMu: 0.06, baseSigma: 0.55, initialPrice: 89000),
      Stock(code: '220002', name: '셀그린', sectorId: SectorId.bio, baseMu: 0.10, baseSigma: 0.65, initialPrice: 41000),
      Stock(code: '220003', name: '휴먼팜', sectorId: SectorId.bio, baseMu: 0.02, baseSigma: 0.50, initialPrice: 12800),
      // 제조
      Stock(code: '330001', name: '대한중공업', sectorId: SectorId.manufacturing, baseMu: 0.05, baseSigma: 0.30, initialPrice: 152000),
      Stock(code: '330002', name: '미래모빌리티', sectorId: SectorId.manufacturing, baseMu: 0.09, baseSigma: 0.40, initialPrice: 47500),
      Stock(code: '330003', name: '한성정밀', sectorId: SectorId.manufacturing, baseMu: 0.04, baseSigma: 0.35, initialPrice: 23600),
      // 금융
      Stock(code: '440001', name: '국민홀딩스', sectorId: SectorId.finance, baseMu: 0.05, baseSigma: 0.20, initialPrice: 58200),
      Stock(code: '440002', name: '서울증권', sectorId: SectorId.finance, baseMu: 0.06, baseSigma: 0.35, initialPrice: 13450),
      Stock(code: '440003', name: '든든보험', sectorId: SectorId.finance, baseMu: 0.04, baseSigma: 0.22, initialPrice: 31900),
      // 에너지
      Stock(code: '550001', name: '한국에너지', sectorId: SectorId.energy, baseMu: 0.04, baseSigma: 0.28, initialPrice: 21500),
      Stock(code: '550002', name: '그린수소', sectorId: SectorId.energy, baseMu: 0.10, baseSigma: 0.75, initialPrice: 8900),
      Stock(code: '550003', name: '오일뱅크스', sectorId: SectorId.energy, baseMu: 0.05, baseSigma: 0.38, initialPrice: 44300),

      // ---- 미장 (가격 단위: 달러) ----
      Stock(code: 'PNPL', name: '파인애플', sectorId: SectorId.tech, baseMu: 0.09, baseSigma: 0.28, initialPrice: 185, exchangeId: ExchangeId.us),
      Stock(code: 'MHRD', name: '마이크로하드', sectorId: SectorId.tech, baseMu: 0.10, baseSigma: 0.26, initialPrice: 410, exchangeId: ExchangeId.us),
      Stock(code: 'GGOL', name: '구골', sectorId: SectorId.tech, baseMu: 0.09, baseSigma: 0.30, initialPrice: 175, exchangeId: ExchangeId.us),
      Stock(code: 'NVDO', name: '엔비디오', sectorId: SectorId.tech, baseMu: 0.15, baseSigma: 0.55, initialPrice: 130, exchangeId: ExchangeId.us),
      Stock(code: 'AMZR', name: '아마존강', sectorId: SectorId.tech, baseMu: 0.10, baseSigma: 0.35, initialPrice: 180, exchangeId: ExchangeId.us),
      Stock(code: 'TSLO', name: '테슬로', sectorId: SectorId.manufacturing, baseMu: 0.08, baseSigma: 0.60, initialPrice: 250, exchangeId: ExchangeId.us),
      Stock(code: 'BOEN', name: '보잉턴', sectorId: SectorId.manufacturing, baseMu: 0.04, baseSigma: 0.35, initialPrice: 190, exchangeId: ExchangeId.us),
      Stock(code: 'JPBK', name: '제이피뱅크', sectorId: SectorId.finance, baseMu: 0.06, baseSigma: 0.25, initialPrice: 200, exchangeId: ExchangeId.us),
      Stock(code: 'PFZN', name: '화이젠', sectorId: SectorId.bio, baseMu: 0.03, baseSigma: 0.40, initialPrice: 30, exchangeId: ExchangeId.us),
      Stock(code: 'XNOL', name: '엑슨오일', sectorId: SectorId.energy, baseMu: 0.05, baseSigma: 0.30, initialPrice: 110, exchangeId: ExchangeId.us),

      // ---- IPO 대기 풀 (게임 중 확률적으로 신규 상장, 그 전엔 안 보임) ----
      Stock(code: '110004', name: '퀀텀칩스', sectorId: SectorId.tech, baseMu: 0.14, baseSigma: 0.80, initialPrice: 24000, status: ListingStatus.unlisted),
      Stock(code: '220004', name: '지노믹스랩', sectorId: SectorId.bio, baseMu: 0.08, baseSigma: 0.70, initialPrice: 19500, status: ListingStatus.unlisted),
      Stock(code: '550004', name: '스타배터리', sectorId: SectorId.energy, baseMu: 0.11, baseSigma: 0.65, initialPrice: 36000, status: ListingStatus.unlisted),
      Stock(code: 'RBTX', name: '로보틱스엑스', sectorId: SectorId.manufacturing, baseMu: 0.12, baseSigma: 0.70, initialPrice: 45, exchangeId: ExchangeId.us, status: ListingStatus.unlisted),
    ];
