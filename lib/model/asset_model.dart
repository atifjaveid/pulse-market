class AssetModel {
  final String symbol;
  final String name;
  final String type; // 'stock' or 'crypto'
  final double price;
  final double change;
  final double changePercent;
  final double high24h;
  final double low24h;
  final double volume;
  final double marketCap;
  final String logoEmoji;
  final List<double> sparklineData;
  final String color;
  final DateTime? lastUpdated;

  const AssetModel({
    required this.symbol,
    required this.name,
    required this.type,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.high24h,
    required this.low24h,
    required this.volume,
    required this.marketCap,
    required this.logoEmoji,
    required this.sparklineData,
    required this.color,
    this.lastUpdated,
  });

  bool get isGain => changePercent >= 0;

  AssetModel copyWith({
    double? price,
    double? change,
    double? changePercent,
    double? high24h,
    double? low24h,
    double? volume,
    double? marketCap,
    List<double>? sparklineData,
    DateTime? lastUpdated,
  }) {
    return AssetModel(
      symbol:        symbol,
      name:          name,
      type:          type,
      price:         price         ?? this.price,
      change:        change        ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      high24h:       high24h       ?? this.high24h,
      low24h:        low24h        ?? this.low24h,
      volume:        volume        ?? this.volume,
      marketCap:     marketCap     ?? this.marketCap,
      logoEmoji:     logoEmoji,
      sparklineData: sparklineData ?? this.sparklineData,
      color:         color,
      lastUpdated:   lastUpdated   ?? this.lastUpdated,
    );
  }
}

class CandleData {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const CandleData({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}

class AlertModel {
  final String symbol;
  final double minPrice;
  final double maxPrice;
  final bool isActive;
  final String id;

  const AlertModel({
    required this.symbol,
    required this.minPrice,
    required this.maxPrice,
    required this.isActive,
    required this.id,
  });
}
