import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../model/asset_model.dart';
import '../services/market_service.dart';
import '../theme.dart';
import '../widgets/sparklinr.dart';
import '../widgets/live_badge.dart';
import 'asset_detail_screen.dart';

class _Holding {
  final String symbol;
  final double qty;
  const _Holding(this.symbol, this.qty);
}

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  static const List<_Holding> _holdings = [
    _Holding('BTC',  0.35),
    _Holding('ETH',  4.2),
    _Holding('AAPL', 15.0),
    _Holding('NVDA', 5.0),
    _Holding('SOL',  12.5),
  ];

  List<double> _portfolioHistory = [];
  StreamSubscription<List<AssetModel>>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sub = context.read<MarketService>().tickStream.listen(_onTick);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onTick(List<AssetModel> assets) {
    if (!mounted) return;
    final total = _computeTotal(assets);
    setState(() {
      if (_portfolioHistory.length >= 30) _portfolioHistory.removeAt(0);
      _portfolioHistory.add(total);
    });
  }

  double _computeTotal(List<AssetModel> assets) =>
      _holdings.fold(0.0, (s, h) {
        final a = assets.firstWhere((a) => a.symbol == h.symbol,
            orElse: () => _dead(h.symbol));
        return s + h.qty * a.price;
      });

  static AssetModel _dead(String sym) => AssetModel(
        symbol: sym, name: sym, type: 'stock',
        price: 0, change: 0, changePercent: 0,
        high24h: 0, low24h: 0, volume: 0, marketCap: 0,
        logoEmoji: '', sparklineData: const [], color: '',
      );

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketService>(builder: (context, svc, _) {
      if (svc.isLoading) {
        return const Scaffold(
          backgroundColor: AppTheme.background,
          body: Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
        );
      }

      final assets = svc.assets;
      final rows = _holdings.map((h) {
        final a = assets.firstWhere((a) => a.symbol == h.symbol,
            orElse: () => _dead(h.symbol));
        return _LiveHolding(h, a);
      }).toList();

      final totalValue  = rows.fold(0.0, (s, h) => s + h.currentValue);
      final totalChange = rows.fold(0.0, (s, h) => s + h.dayChange);
      final pctChange   = totalValue > 0 ? (totalChange / totalValue) * 100 : 0.0;
      final isGain      = totalChange >= 0;

      if (_portfolioHistory.isEmpty && totalValue > 0) {
        _portfolioHistory = List.generate(
            10, (i) => totalValue * (0.95 + i * 0.005));
      }

      return Scaffold(
        backgroundColor: AppTheme.background,
        body: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _header()),
          SliverToBoxAdapter(child: _card(totalValue, totalChange, pctChange, isGain)),
          SliverToBoxAdapter(child: _allocation(rows, totalValue)),
          SliverToBoxAdapter(child: _holdingsTitle()),
          SliverList(delegate: SliverChildBuilderDelegate(
            (_, i) => _row(context, rows[i]),
            childCount: rows.length,
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ]),
      );
    });
  }

  Widget _header() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text('Portfolio', style: GoogleFonts.outfit(
              fontSize: 28, fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary, letterSpacing: -0.5)),
            const SizedBox(width: 10),
           // const LiveBadge(),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.add_rounded, color: AppTheme.primary, size: 16),
              const SizedBox(width: 4),
              Text('Add Asset', style: GoogleFonts.outfit(
                  color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    ),
  );

  Widget _card(double total, double change, double pct, bool isGain) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            isGain ? AppTheme.gainGreen.withOpacity(0.15)
                   : AppTheme.lossRed.withOpacity(0.15),
            AppTheme.surface,
          ],
        ),
        border: Border.all(color: isGain
            ? AppTheme.gainGreen.withOpacity(0.3)
            : AppTheme.lossRed.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Total Balance', style: GoogleFonts.spaceGrotesk(
            color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(end: total),
          duration: const Duration(milliseconds: 700),
          builder: (_, val, __) => Text('\$${val.toStringAsFixed(2)}',
              style: GoogleFonts.outfit(
                fontSize: 38, fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary, letterSpacing: -1)),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Icon(isGain ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: isGain ? AppTheme.gainGreen : AppTheme.lossRed, size: 16),
          const SizedBox(width: 4),
          Text(
            '${isGain ? '+' : ''}\$${change.abs().toStringAsFixed(2)} '
            '(${isGain ? '+' : ''}${pct.toStringAsFixed(2)}%) today',
            style: GoogleFonts.spaceGrotesk(
              color: isGain ? AppTheme.gainGreen : AppTheme.lossRed,
              fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ]),
        if (_portfolioHistory.length > 1) ...[
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: SparklineWidget(
              data: _portfolioHistory,
              color: isGain ? AppTheme.gainGreen : AppTheme.lossRed,
              height: 48, showFill: true,
            ),
          ),
        ],
      ]),
    );
  }

  Widget _allocation(List<_LiveHolding> rows, double total) {
    if (total == 0) return const SizedBox.shrink();
    const colors = [
      AppTheme.warningOrange, Color(0xFF627EEA), Color(0xFFA2AAAD),
      AppTheme.gainGreen,     AppTheme.primary,
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Allocation', style: GoogleFonts.outfit(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(children: rows.asMap().entries.map((e) {
            final flex = (e.value.currentValue / total * 100).round().clamp(1, 100);
            return Expanded(
              flex: flex,
              child: Container(height: 12, color: colors[e.key % colors.length]),
            );
          }).toList()),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16, runSpacing: 8,
          children: rows.asMap().entries.map((e) {
            final pct = (e.value.currentValue / total * 100).toStringAsFixed(1);
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                  color: colors[e.key % colors.length], shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${e.value.holding.symbol} $pct%',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ]);
          }).toList(),
        ),
      ]),
    );
  }

  Widget _holdingsTitle() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
    child: Text('Holdings', style: GoogleFonts.outfit(
        fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
  );

  Widget _row(BuildContext context, _LiveHolding lh) {
    final isGain = lh.asset.isGain;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: lh.asset))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(
              lh.asset.logoEmoji.isEmpty ? lh.holding.symbol[0] : lh.asset.logoEmoji,
              style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lh.holding.symbol, style: GoogleFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            Text('${lh.holding.qty} units · \$${_fmt(lh.asset.price)}',
                style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AppTheme.textSecondary)),
          ])),
          if (lh.asset.sparklineData.length > 1)
            SizedBox(
              width: 50, height: 28,
              child: SparklineWidget(
                data: lh.asset.sparklineData,
                color: isGain ? AppTheme.gainGreen : AppTheme.lossRed,
                height: 28),
            ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: lh.currentValue),
              duration: const Duration(milliseconds: 600),
              builder: (_, val, __) => Text('\$${val.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ),
            Text(
              '${isGain ? '+' : ''}\$${lh.dayChange.abs().toStringAsFixed(2)} '
              '(${isGain ? '+' : ''}${lh.asset.changePercent.toStringAsFixed(2)}%)',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  color: isGain ? AppTheme.gainGreen : AppTheme.lossRed,
                  fontWeight: FontWeight.w600),
            ),
          ]),
        ]),
      ),
    );
  }

  String _fmt(double p) {
    if (p > 1000) return p.toStringAsFixed(2);
    if (p > 1)    return p.toStringAsFixed(2);
    return p.toStringAsFixed(4);
  }
}

class _LiveHolding {
  final _Holding holding;
  final AssetModel asset;
  _LiveHolding(this.holding, this.asset);
  double get currentValue => holding.qty * asset.price;
  double get dayChange    => holding.qty * asset.price * asset.changePercent / 100;
}
