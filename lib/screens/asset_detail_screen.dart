import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../model/asset_model.dart';
import '../services/market_service.dart';
import '../theme.dart';
import 'assets_screen.dart';

class AssetDetailScreen extends StatefulWidget {
  final AssetModel asset;
  const AssetDetailScreen({super.key, required this.asset});

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen>
    with SingleTickerProviderStateMixin {
  String _selectedInterval = '1D';
  final intervals = ['1H', '4H', '1D', '1W', '1M'];
  bool _isCandleView = true;
  bool _historyLoading = true;
  List<CandleData> _history = [];

  // Flash animation
  Color? _priceFlash;
  double? _prevPrice;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    final svc = context.read<MarketService>();
    final candles = await svc.getHistory(
      widget.asset.symbol,
      interval: _selectedInterval,
    );
    if (mounted) {
      setState(() {
        _history = candles;
        _historyLoading = false;
      });
    }
  }

  void _onIntervalChanged(String interval) {
    setState(() => _selectedInterval = interval);
    _loadHistory();
  }

  /// Get the live version of this asset from the service
  AssetModel _liveAsset(BuildContext context) {
    final svc = context.watch<MarketService>();
    return svc.assets.firstWhere(
      (a) => a.symbol == widget.asset.symbol,
      orElse: () => widget.asset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final asset = _liveAsset(context);

    // Flash price on change
    if (_prevPrice != null && _prevPrice != asset.price) {
      _priceFlash = asset.price > _prevPrice!
          ? AppTheme.gainGreen.withOpacity(0.15)
          : AppTheme.lossRed.withOpacity(0.15);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _priceFlash = null);
      });
    }
    _prevPrice = asset.price;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: _priceFlash ?? Colors.transparent,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(asset),
            SliverToBoxAdapter(child: _buildPriceHeader(asset)),
            SliverToBoxAdapter(child: _buildChartSection(asset)),
            SliverToBoxAdapter(child: _buildStats(asset)),
            SliverToBoxAdapter(child: _buildPriceHistoryTable()),
            SliverToBoxAdapter(child: _buildActionButtons(asset)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(AssetModel asset) {
    return SliverAppBar(
      backgroundColor: AppTheme.background,
      pinned: true,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 16),
        ),
      ),
      title: Row(
        children: [
          Text(
            asset.logoEmoji.isEmpty ? asset.symbol[0] : asset.logoEmoji,
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    asset.symbol,
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  //const LiveBadge(compact: true),
                ],
              ),
              Text(
                asset.name,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.star_border_rounded,
              color: AppTheme.textSecondary),
        ),
        IconButton(
          onPressed: () => context
              .read<MarketService>()
              .refreshAsset(asset.symbol),
          icon:
              const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildPriceHeader(AssetModel asset) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: asset.price),
            duration: const Duration(milliseconds: 600),
            builder: (_, val, __) => Text(
              '\$${_formatPrice(val)}',
              style: GoogleFonts.outfit(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: asset.isGain
                      ? AppTheme.gainGreenGlow
                      : AppTheme.lossRedGlow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: asset.isGain
                        ? AppTheme.gainGreen.withOpacity(0.3)
                        : AppTheme.lossRed.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      asset.isGain
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: asset.isGain
                          ? AppTheme.gainGreen
                          : AppTheme.lossRed,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${asset.isGain ? '+' : ''}\$${asset.change.abs().toStringAsFixed(2)} (${asset.isGain ? '+' : ''}${asset.changePercent.toStringAsFixed(2)}%)',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: asset.isGain
                            ? AppTheme.gainGreen
                            : AppTheme.lossRed,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (asset.lastUpdated != null)
                Text(
                  'Updated ${_timeAgo(asset.lastUpdated!)}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, color: AppTheme.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(AssetModel asset) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      _viewToggleBtn(Icons.candlestick_chart_rounded, true),
                      _viewToggleBtn(Icons.show_chart_rounded, false),
                    ],
                  ),
                ),
                Row(
                  children:
                      intervals.map((i) => _intervalBtn(i)).toList(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: _historyLoading
                ? const SizedBox(
                    height: 220,
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary, strokeWidth: 2),
                    ),
                  )
                : _isCandleView
                    ? _buildCandleChart(asset)
                    : _buildLineChart(asset),
          ),
        ],
      ),
    );
  }

  Widget _viewToggleBtn(IconData icon, bool isCandle) {
    final isActive = _isCandleView == isCandle;
    return GestureDetector(
      onTap: () => setState(() => _isCandleView = isCandle),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon,
            color: isActive ? AppTheme.background : AppTheme.textMuted,
            size: 16),
      ),
    );
  }

  Widget _intervalBtn(String interval) {
    final isActive = _selectedInterval == interval;
    return GestureDetector(
      onTap: () => _onIntervalChanged(interval),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color:
              isActive ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: AppTheme.primary.withOpacity(0.4))
              : null,
        ),
        child: Text(
          interval,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive ? AppTheme.primary : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildCandleChart(AssetModel asset) {
    if (_history.isEmpty) return _buildLineChart(asset);
    final recent = _history.length > 60 ? _history.sublist(_history.length - 60) : _history;
    return SizedBox(
      height: 220,
      child: CustomPaint(
        size: const Size(double.infinity, 220),
        painter: CandlestickPainter(candles: recent),
      ),
    );
  }

  Widget _buildLineChart(AssetModel asset) {
    List<FlSpot> spots;
    if (_history.isNotEmpty) {
      spots = List.generate(
        _history.length,
        (i) => FlSpot(i.toDouble(), _history[i].close),
      );
    } else if (asset.sparklineData.length > 1) {
      spots = List.generate(
        asset.sparklineData.length,
        (i) => FlSpot(i.toDouble(), asset.sparklineData[i]),
      );
    } else {
      // No data yet
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No chart data yet',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13))),
      );
    }
    final color = asset.isGain ? AppTheme.gainGreen : AppTheme.lossRed;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppTheme.divider,
              strokeWidth: 0.5,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (val, _) => Text(
                  '\$${val.toStringAsFixed(0)}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 9, color: AppTheme.textMuted),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withOpacity(0.3),
                    color.withOpacity(0.0)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(AssetModel asset) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistics',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                _statRow('24h High', '\$${_formatPrice(asset.high24h)}',
                    AppTheme.gainGreen),
                const Divider(color: AppTheme.divider, height: 20),
                _statRow('24h Low', '\$${_formatPrice(asset.low24h)}',
                    AppTheme.lossRed),
                const Divider(color: AppTheme.divider, height: 20),
                _statRow('24h Volume', _formatVolume(asset.volume),
                    AppTheme.textSecondary),
                const Divider(color: AppTheme.divider, height: 20),
                _statRow('Market Cap', _formatVolume(asset.marketCap),
                    AppTheme.textSecondary),
                const Divider(color: AppTheme.divider, height: 20),
                _statRow(
                  'Type',
                  asset.type == 'crypto' ? '🪙 Crypto' : '📈 Stock',
                  AppTheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceHistoryTable() {
    if (_history.isEmpty) return const SizedBox.shrink();
    final recent = _history.reversed.take(10).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price History',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                _historyHeader(),
                ...recent.asMap().entries.map((e) =>
                    _historyRow(e.value, e.key == recent.length - 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
              child: Text('Date',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, color: AppTheme.textMuted))),
          Expanded(
              child: Text('Open',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, color: AppTheme.textMuted))),
          Expanded(
              child: Text('Close',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, color: AppTheme.textMuted))),
          Expanded(
              child: Text('Change',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, color: AppTheme.textMuted))),
        ],
      ),
    );
  }

  Widget _historyRow(CandleData c, bool isLast) {
    final chg = c.close - c.open;
    final chgPct = c.open != 0 ? (chg / c.open) * 100 : 0.0;
    final isGain = chg >= 0;
    final color = isGain ? AppTheme.gainGreen : AppTheme.lossRed;

    return Column(
      children: [
        const Divider(color: AppTheme.divider, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${c.date.day}/${c.date.month}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  '\$${_formatPrice(c.open)}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  '\$${_formatPrice(c.close)}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                ),
              ),
              Expanded(
                child: Text(
                  '${isGain ? '+' : ''}${chgPct.toStringAsFixed(2)}%',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 14, color: AppTheme.textSecondary)),
        Text(value,
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor)),
      ],
    );
  }

  Widget _buildActionButtons(AssetModel asset) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AlertsScreen(preselectedAsset: asset)),
              ),
              icon: const Icon(Icons.notifications_active_rounded, size: 18),
              label: Text('Set Alert',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Add to Portfolio',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.background,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price > 1000) return price.toStringAsFixed(2);
    if (price > 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(4);
  }

  String _formatVolume(double vol) {
    if (vol >= 1e12) return '\$${(vol / 1e12).toStringAsFixed(2)}T';
    if (vol >= 1e9) return '\$${(vol / 1e9).toStringAsFixed(2)}B';
    if (vol >= 1e6) return '\$${(vol / 1e6).toStringAsFixed(2)}M';
    return '\$${vol.toStringAsFixed(0)}';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ── Custom Candlestick Painter ───────────────────────────────────────────────
class CandlestickPainter extends CustomPainter {
  final List<CandleData> candles;
  CandlestickPainter({required this.candles});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    final minLow =
        candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final maxHigh =
        candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final range = maxHigh - minLow;
    if (range == 0) return;

    final candleWidth = (size.width / candles.length) * 0.6;
    final gap = size.width / candles.length;

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final x = i * gap + gap / 2;
      final isGain = c.close >= c.open;
      final color = isGain ? AppTheme.gainGreen : AppTheme.lossRed;

      final topY = size.height - ((c.high - minLow) / range) * size.height;
      final botY = size.height - ((c.low - minLow) / range) * size.height;
      final openY = size.height - ((c.open - minLow) / range) * size.height;
      final closeY =
          size.height - ((c.close - minLow) / range) * size.height;

      canvas.drawLine(Offset(x, topY), Offset(x, botY),
          Paint()..color = color.withOpacity(0.6)..strokeWidth = 1);

      final bodyTop = isGain ? closeY : openY;
      final bodyBot = isGain ? openY : closeY;
      final bodyHeight = (bodyBot - bodyTop).abs().clamp(1.0, double.infinity);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - candleWidth / 2, bodyTop, candleWidth, bodyHeight),
          const Radius.circular(1),
        ),
        Paint()..color = color.withOpacity(0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CandlestickPainter old) =>
      old.candles != candles;
}
