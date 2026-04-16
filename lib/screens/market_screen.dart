import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../model/asset_model.dart';
import '../services/market_service.dart';
import '../theme.dart';
import '../widgets/asset_card.dart';
import '../widgets/live_badge.dart';
import 'asset_detail_screen.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _sortBy = 'Market Cap';
  String _searchQuery = '';

  final List<String> sortOptions = ['Market Cap', 'Price', 'Change %', 'Volume'];

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


  List<AssetModel> _filtered(List<AssetModel> all, String type) {
    // Always create a mutable copy first
    var list = (type == 'all'
        ? List<AssetModel>.of(all)
        : all.where((a) => a.type == type).toList());

    if (_searchQuery.isNotEmpty) {
      list = list
          .where((a) =>
      a.symbol.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    switch (_sortBy) {
      case 'Price':
        list.sort((a, b) => b.price.compareTo(a.price));
      case 'Change %':
        list.sort((a, b) => b.changePercent.compareTo(a.changePercent));
      case 'Volume':
        list.sort((a, b) => b.volume.compareTo(a.volume));
      default:
        list.sort((a, b) => b.marketCap.compareTo(a.marketCap));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketService>(builder: (context, svc, _) {
      if (svc.isLoading) {
        return const Scaffold(
          backgroundColor: AppTheme.background,
          body: Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
        );
      }
      if (svc.error != null && svc.assets.isEmpty) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, color: AppTheme.lossRed, size: 48),
              const SizedBox(height: 16),
              Text('Could not load markets', style: GoogleFonts.outfit(
                  color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => svc.refreshAll(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text('Retry', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: AppTheme.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          )),
        );
      }
      final assets = svc.assets;
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(svc),
              _buildSearchBar(),
              _buildSortRow(),
              _buildTabs(),
              Expanded(child: _buildTabContent(assets)),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildHeader(MarketService svc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Text(
            'Markets',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 10),
         // const LiveBadge(),
          const Spacer(),
          GestureDetector(
            onTap: () => context.read<MarketService>().refreshAll(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: AppTheme.primary, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: GoogleFonts.spaceGrotesk(
            color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search stocks, crypto...',
          hintStyle: GoogleFonts.spaceGrotesk(
              color: AppTheme.textMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.textMuted, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSortRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        itemCount: sortOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final opt = sortOptions[i];
          final isActive = _sortBy == opt;
          return GestureDetector(
            onTap: () => setState(() => _sortBy = opt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primary : AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? AppTheme.primary : AppTheme.cardBorder,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                opt,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? AppTheme.background
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          labelColor: AppTheme.background,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle:
              GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Crypto'),
            Tab(text: 'Stocks'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(List<AssetModel> assets) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildList(_filtered(assets, 'all')),
        _buildList(_filtered(assets, 'crypto')),
        _buildList(_filtered(assets, 'stock')),
      ],
    );
  }

  Widget _buildList(List<AssetModel> list) {
    if (list.isEmpty) {
      return Center(
        child: Text('No results found',
            style: GoogleFonts.spaceGrotesk(color: AppTheme.textMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => AssetCard(
        asset: list[i],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AssetDetailScreen(asset: list[i])),
        ),
      ),
    );
  }
}
