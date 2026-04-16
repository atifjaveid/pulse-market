import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../model/asset_model.dart';

class MarketService extends ChangeNotifier {
  // ── CoinGecko (crypto) — no key needed ──────────────────────────────────────
  static const String _cgBase = 'https://api.coingecko.com/api/v3';

  // ── Alpha Vantage (stocks) — free key from alphavantage.co ──────────────────
  static const String _avKey  = '121DFXEOCAHH5GYI';
  static const String _avBase = 'https://www.alphavantage.co/query';

  static const Duration _timeout      = Duration(seconds: 10);
  static const Duration _pollInterval = Duration(seconds: 60);

  // CoinGecko IDs for crypto
  static const Map<String, String> _cgIds = {
    'BTC': 'bitcoin',
    'ETH': 'ethereum',
    'SOL': 'solana',
    'BNB': 'binancecoin',
  };

  static const List<_AssetDef> _defs = [
    _AssetDef('BTC',  'Bitcoin',      'crypto', '₿',  '#F7931A'),
    _AssetDef('ETH',  'Ethereum',     'crypto', 'Ξ',  '#627EEA'),
    _AssetDef('SOL',  'Solana',       'crypto', '◎',  '#9945FF'),
    _AssetDef('BNB',  'BNB Chain',    'crypto', '◆',  '#F3BA2F'),
    _AssetDef('AAPL', 'Apple Inc.',   'stock',  '',   '#A2AAAD'),
    _AssetDef('TSLA', 'Tesla Inc.',   'stock',  '⚡',  '#E82127'),
    _AssetDef('NVDA', 'NVIDIA Corp.', 'stock',  '🟢', '#76B900'),
    _AssetDef('MSFT', 'Microsoft',    'stock',  '🪟', '#00A4EF'),
  ];

  List<AssetModel> _assets = [];
  final Map<String, List<CandleData>> _history = {};
  bool    _isLoading = true;
  String? _error;
  Timer?  _pollTimer;

  List<AssetModel> get assets    => List.unmodifiable(_assets);
  bool             get isLoading => _isLoading;
  String?          get error     => _error;

  final _tick = StreamController<List<AssetModel>>.broadcast();
  Stream<List<AssetModel>> get tickStream => _tick.stream;

  MarketService() { _init(); }

  Future<void> _init() async {
    await _fetchAll();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _fetchAll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tick.close();
    super.dispose();
  }

  bool get mounted => !_tick.isClosed;

  Future<void> refreshAll() => _fetchAll();

  Future<void> refreshAsset(String symbol) async {
    final idx = _assets.indexWhere((a) => a.symbol == symbol);
    if (idx < 0) return;
    final def = _defs.firstWhere((d) => d.symbol == symbol,
        orElse: () => _defs.first);
    AssetModel? updated;
    if (def.type == 'crypto') {
      final cgData = await _fetchCryptoAll();
      updated = cgData[symbol];
    } else {
      updated = await _fetchStock(def, _assets[idx]);
    }
    if (updated != null && mounted) {
      _assets[idx] = updated;
      notifyListeners();
      _tick.add(List.unmodifiable(_assets));
    }
  }

  Future<List<CandleData>> getHistory(String symbol,
      {String interval = '1D', bool forceRefresh = false}) async {
    final key = '${symbol}_$interval';
    if (!forceRefresh && _history.containsKey(key)) return _history[key]!;
    final def = _defs.firstWhere((d) => d.symbol == symbol,
        orElse: () => _defs.first);
    final candles = def.type == 'crypto'
        ? await _fetchCryptoHistory(def, interval)
        : await _fetchStockHistory(def, interval);
    _history[key] = candles;
    return candles;
  }

  // ── Core fetch ───────────────────────────────────────────────────────────────

  Future<void> _fetchAll() async {
    try {
      final prev = {for (final a in _assets) a.symbol: a};

      // Fetch all crypto in one call
      final cgData = await _fetchCryptoAll();

      // Fetch stocks concurrently
      final stockDefs = _defs.where((d) => d.type == 'stock').toList();
      final stockResults = await Future.wait(
        stockDefs.map((d) => _fetchStock(d, prev[d.symbol])),
      );

      final newAssets = <AssetModel>[];
      for (final def in _defs) {
        if (def.type == 'crypto') {
          newAssets.add(cgData[def.symbol] ?? prev[def.symbol] ?? _placeholder(def));
        } else {
          final idx = stockDefs.indexWhere((d) => d.symbol == def.symbol);
          newAssets.add(stockResults[idx] ?? prev[def.symbol] ?? _placeholder(def));
        }
      }

      _assets    = newAssets;
      _isLoading = false;
      _error     = null;
      notifyListeners();
      _tick.add(List.unmodifiable(_assets));
    } catch (e) {
      _isLoading = false;
      _error     = e.toString();
      notifyListeners();
    }
  }

  // ── CoinGecko ────────────────────────────────────────────────────────────────

  Future<Map<String, AssetModel>> _fetchCryptoAll() async {
    final ids = _cgIds.values.join(',');
    final url = '$_cgBase/coins/markets'
        '?vs_currency=usd'
        '&ids=$ids'
        '&order=market_cap_desc'
        '&sparkline=true'
        '&price_change_percentage=24h';

    try {
      debugPrint('CG ▶ $url');
      final resp = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      debugPrint('CG ◀ ${resp.statusCode}');
      if (resp.statusCode != 200) return {};

      final list = jsonDecode(resp.body) as List;
      final result = <String, AssetModel>{};

      // Reverse map: coingecko_id -> symbol
      final idToSymbol = {for (final e in _cgIds.entries) e.value: e.key};

      for (final item in list) {
        final symbol = idToSymbol[item['id']];
        if (symbol == null) continue;
        final def = _defs.firstWhere((d) => d.symbol == symbol);

        final price     = _d(item['current_price'])  ?? 0.0;
        final chAbs     = _d(item['price_change_24h']) ?? 0.0;
        final chPct     = _d(item['price_change_percentage_24h']) ?? 0.0;
        final high      = _d(item['high_24h'])        ?? price;
        final low       = _d(item['low_24h'])         ?? price;
        final volume    = _d(item['total_volume'])    ?? 0.0;
        final marketCap = _d(item['market_cap'])      ?? 0.0;

        // Sparkline from CoinGecko (last 7 days, ~168 points) — take last 30
        final rawSpark = (item['sparkline_in_7d']?['price'] as List?)
            ?.map((v) => _d(v) ?? 0.0)
            .toList() ??
            [];
        final spark = rawSpark.length > 30
            ? rawSpark.sublist(rawSpark.length - 30)
            : rawSpark;

        result[symbol] = AssetModel(
          symbol:        symbol,
          name:          def.name,
          type:          'crypto',
          price:         price,
          change:        chAbs,
          changePercent: chPct,
          high24h:       high,
          low24h:        low,
          volume:        volume,
          marketCap:     marketCap,
          logoEmoji:     def.emoji,
          sparklineData: spark,
          color:         def.color,
          lastUpdated:   DateTime.now(),
        );
      }
      return result;
    } on TimeoutException {
      debugPrint('CG timeout');
      return {};
    } catch (e) {
      debugPrint('CG error: $e');
      return {};
    }
  }

  Future<List<CandleData>> _fetchCryptoHistory(
      _AssetDef def, String interval) async {
    final cgId = _cgIds[def.symbol];
    if (cgId == null) return [];

    // Map interval to CoinGecko days param
    final days = switch (interval) {
      '1H' => '1',
      '4H' => '7',
      '1W' => '30',
      '1M' => '90',
      _    => '30',
    };

    try {
      final url = '$_cgBase/coins/$cgId/ohlc?vs_currency=usd&days=$days';
      final resp = await http.get(Uri.parse(url)).timeout(_timeout);
      if (resp.statusCode != 200) return [];

      final list = jsonDecode(resp.body) as List;
      return list.map((d) {
        final arr = d as List;
        return CandleData(
          date:   DateTime.fromMillisecondsSinceEpoch((arr[0] as int)),
          open:   _d(arr[1]) ?? 0,
          high:   _d(arr[2]) ?? 0,
          low:    _d(arr[3]) ?? 0,
          close:  _d(arr[4]) ?? 0,
          volume: 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('CG history error: $e');
      return [];
    }
  }

  // ── Alpha Vantage ────────────────────────────────────────────────────────────

  Future<AssetModel?> _fetchStock(_AssetDef def, AssetModel? prev) async {
    try {
      final url = '$_avBase?function=GLOBAL_QUOTE'
          '&symbol=${def.symbol}'
          '&apikey=$_avKey';

      debugPrint('AV ▶ ${def.symbol}');
      final resp = await http.get(Uri.parse(url)).timeout(_timeout);
      debugPrint('AV ◀ ${resp.statusCode}');

      if (resp.statusCode != 200) return null;

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final quote = json['Global Quote'] as Map<String, dynamic>?;
      if (quote == null || quote.isEmpty) return null;

      final price  = _d(quote['05. price'])          ?? 0.0;
      final open   = _d(quote['02. open'])            ?? price;
      final high   = _d(quote['03. high'])            ?? price;
      final low    = _d(quote['04. low'])             ?? price;
      final chAbs  = _d(quote['09. change'])          ?? (price - open);
      final chPctS = (quote['10. change percent'] as String?)
          ?.replaceAll('%', '') ??
          '0';
      final chPct  = double.tryParse(chPctS) ?? 0.0;
      final volume = _d(quote['06. volume'])          ?? 0.0;

      final spark = List<double>.from(prev?.sparklineData ?? []);
      if (price > 0) {
        if (spark.length >= 30) spark.removeAt(0);
        spark.add(price);
      }

      return AssetModel(
        symbol:        def.symbol,
        name:          def.name,
        type:          'stock',
        price:         price,
        change:        chAbs,
        changePercent: chPct,
        high24h:       high,
        low24h:        low,
        volume:        volume,
        marketCap:     prev?.marketCap ?? 0,
        logoEmoji:     def.emoji,
        sparklineData: spark,
        color:         def.color,
        lastUpdated:   DateTime.now(),
      );
    } on TimeoutException {
      debugPrint('AV timeout for ${def.symbol}');
      return null;
    } catch (e) {
      debugPrint('AV error for ${def.symbol}: $e');
      return null;
    }
  }

  Future<List<CandleData>> _fetchStockHistory(
      _AssetDef def, String interval) async {
    try {
      // Use daily data for simplicity (free tier friendly)
      final url = '$_avBase?function=TIME_SERIES_DAILY'
          '&symbol=${def.symbol}'
          '&outputsize=compact'
          '&apikey=$_avKey';

      final resp = await http.get(Uri.parse(url)).timeout(_timeout);
      if (resp.statusCode != 200) return [];

      final json   = jsonDecode(resp.body) as Map<String, dynamic>;
      final series = json['Time Series (Daily)'] as Map<String, dynamic>?;
      if (series == null) return [];

      return series.entries.map((e) {
        final d = e.value as Map<String, dynamic>;
        return CandleData(
          date:   DateTime.parse(e.key),
          open:   _d(d['1. open'])   ?? 0,
          high:   _d(d['2. high'])   ?? 0,
          low:    _d(d['3. low'])    ?? 0,
          close:  _d(d['4. close'])  ?? 0,
          volume: _d(d['5. volume']) ?? 0,
        );
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      debugPrint('AV history error: $e');
      return [];
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static double? _d(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  AssetModel _placeholder(_AssetDef def) => AssetModel(
    symbol: def.symbol, name: def.name, type: def.type,
    price: 0, change: 0, changePercent: 0,
    high24h: 0, low24h: 0, volume: 0, marketCap: 0,
    logoEmoji: def.emoji, sparklineData: const [], color: def.color,
  );
}

class _AssetDef {
  final String symbol;
  final String name;
  final String type;
  final String emoji;
  final String color;
  const _AssetDef(this.symbol, this.name, this.type, this.emoji, this.color);
}