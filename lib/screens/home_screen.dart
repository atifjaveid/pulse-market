import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../model/asset_model.dart';
import '../services/market_service.dart';
import '../theme.dart';
import '../widgets/asset_card.dart';
import '../widgets/sparklinr.dart';
import '../widgets/live_badge.dart';
import '../widgets/debug_overlay.dart';
import 'asset_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketService>(builder: (context, svc, _) {
      if (svc.isLoading) return const _LoadingState();
      if (svc.error != null && svc.assets.isEmpty) {
        return _ErrorState(
          error: svc.error!,
          onRetry: () => svc.refreshAll(),
        );
      }

      final assets  = svc.assets;
      final crypto  = assets.where((a) => a.type == 'crypto').toList();
      final stocks  = assets.where((a) => a.type == 'stock').toList();

      return Scaffold(
        backgroundColor: AppTheme.background,
        body: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildMarketSummary(assets)),
            SliverToBoxAdapter(child: _buildTrendingSection(assets)),
            SliverToBoxAdapter(child: _buildTabSection(assets, crypto, stocks)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      );
    });
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppTheme.background,
      floating: true,
      pinned: false,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Live Markets 👋',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text('PulseMarket',
                          style: GoogleFonts.outfit(
                            fontSize: 22, fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary, letterSpacing: -0.5,
                          )),
                      const SizedBox(width: 8),
                     // const LiveBadge(),
                    ]),
                  ],
                ),
                Row(children: [
                  const DebugOverlay(),
                  const SizedBox(width: 8),
                  _iconBtn(Icons.refresh_rounded,
                      onTap: () => context.read<MarketService>().refreshAll()),
                  const SizedBox(width: 8),
                  _iconBtn(Icons.person_outline_rounded),
                ]),
              ],
            ),
          ),
        ),
      ),
      expandedHeight: 80,
    );
  }

  Widget _iconBtn(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Icon(icon, color: AppTheme.textSecondary, size: 20),
      ),
    );
  }

  Widget _buildMarketSummary(List<AssetModel> assets) {
    // All values computed live from the asset list
    final totalCap  = assets.fold(0.0, (s, a) => s + a.marketCap);
    final avgChange = assets.isEmpty ? 0.0
        : assets.fold(0.0, (s, a) => s + a.changePercent) / assets.length;
    final btc = assets.firstWhere((a) => a.symbol == 'BTC',
        orElse: () => assets.first);
    final allCap  = assets.fold(0.0, (s, a) => s + a.marketCap);
    final btcDom  = allCap > 0
        ? (btc.marketCap / allCap * 100).toStringAsFixed(1)
        : '–';
    final capStr  = totalCap >= 1e12
        ? '\$${(totalCap / 1e12).toStringAsFixed(2)}T'
        : totalCap >= 1e9
            ? '\$${(totalCap / 1e9).toStringAsFixed(1)}B'
            : '–';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0D2240), Color(0xFF091628)],
        ),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
        boxShadow: [BoxShadow(
          color: AppTheme.primary.withOpacity(0.08),
          blurRadius: 20, spreadRadius: 2,
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Total Market Cap',
                    style: GoogleFonts.spaceGrotesk(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(capStr,
                    style: GoogleFonts.outfit(
                      color: AppTheme.textPrimary,
                      fontSize: 28, fontWeight: FontWeight.w800,
                    )),
              ]),
              _changePill(avgChange),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            _summaryChip('BTC Dom', '$btcDom%', AppTheme.warningOrange),
            const SizedBox(width: 8),
            _summaryChip('BTC Price', '\$${_fmtPrice(btc.price)}',
                btc.isGain ? AppTheme.gainGreen : AppTheme.lossRed),
            const SizedBox(width: 8),
            _summaryChip('Assets', '${assets.length} Live', AppTheme.primary),
          ]),
        ],
      ),
    );
  }

  Widget _changePill(double pct) {
    final isGain = pct >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isGain ? AppTheme.gainGreenGlow : AppTheme.lossRedGlow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGain
              ? AppTheme.gainGreen.withOpacity(0.3)
              : AppTheme.lossRed.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(
          isGain ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          color: isGain ? AppTheme.gainGreen : AppTheme.lossRed,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '${isGain ? '+' : ''}${pct.toStringAsFixed(2)}%',
          style: GoogleFonts.spaceGrotesk(
            color: isGain ? AppTheme.gainGreen : AppTheme.lossRed,
            fontSize: 13, fontWeight: FontWeight.w700,
          ),
        ),
      ]),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 10, color: AppTheme.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }

  Widget _buildTrendingSection(List<AssetModel> assets) {
    // Top 4 by absolute % change = genuinely most volatile
    final trending = List<AssetModel>.from(assets)
      ..sort((a, b) => b.changePercent.abs().compareTo(a.changePercent.abs()));
    final top = trending.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🔥 Trending',
                  style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              Text('See all',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 13, color: AppTheme.primary)),
            ],
          ),
        ),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: top.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _trendingCard(top[i]),
          ),
        ),
      ],
    );
  }

  Widget _trendingCard(AssetModel asset) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: asset))),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                asset.logoEmoji.isEmpty ? asset.symbol[0] : asset.logoEmoji,
                style: const TextStyle(fontSize: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: asset.isGain ? AppTheme.gainGreenGlow : AppTheme.lossRedGlow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${asset.isGain ? '+' : ''}${asset.changePercent.toStringAsFixed(2)}%',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: asset.isGain ? AppTheme.gainGreen : AppTheme.lossRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(asset.symbol,
              style: GoogleFonts.outfit(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text('\$${_fmtPrice(asset.price)}',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          if (asset.sparklineData.length > 1)
            SparklineWidget(
              data: asset.sparklineData,
              color: asset.isGain ? AppTheme.gainGreen : AppTheme.lossRed,
              height: 30,
            ),
        ]),
      ),
    );
  }

  Widget _buildTabSection(List<AssetModel> all, List<AssetModel> crypto,
      List<AssetModel> stocks) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10)),
            labelColor: AppTheme.background,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle:
                GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [Tab(text: 'All'), Tab(text: 'Crypto'), Tab(text: 'Stocks')],
          ),
        ),
      ),
      SizedBox(
        height: 420,
        child: TabBarView(
          controller: _tabController,
          children: [
            _assetList(all),
            _assetList(crypto),
            _assetList(stocks),
          ],
        ),
      ),
    ]);
  }

  Widget _assetList(List<AssetModel> list) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => AssetCard(
        asset: list[i],
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: list[i]))),
      ),
    );
  }

  String _fmtPrice(double p) {
    if (p > 1000) return p.toStringAsFixed(2);
    if (p > 1)    return p.toStringAsFixed(2);
    return p.toStringAsFixed(4);
  }
}

// ── Loading state ─────────────────────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(
            width: 40, height: 40,
            child: CircularProgressIndicator(
                color: AppTheme.primary, strokeWidth: 2),
          ),
          const SizedBox(height: 16),
          Text('Fetching live prices…',
              style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.textSecondary, fontSize: 14)),
        ]),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppTheme.lossRed, size: 48),
            const SizedBox(height: 16),
            Text('Could not load prices',
                style: GoogleFonts.outfit(
                    color: AppTheme.textPrimary,
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                    color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Retry',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.background,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
