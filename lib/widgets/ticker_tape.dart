import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../model/asset_model.dart';
import '../services/market_service.dart';
import '../theme.dart';

/// Horizontally scrolling live ticker tape — auto-scrolls continuously.
class TickerTape extends StatefulWidget {
  const TickerTape({super.key});

  @override
  State<TickerTape> createState() => _TickerTapeState();
}

class _TickerTapeState extends State<TickerTape>
    with SingleTickerProviderStateMixin {
  late ScrollController _scroll;
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addListener(_tick);
    // Start after first frame so layout is complete
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _anim.repeat());
  }

  void _tick() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    final target = _anim.value * max;
    _scroll.jumpTo(target);
  }

  @override
  void dispose() {
    _anim.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketService>(builder: (context, svc, _) {
      final assets = svc.assets;
      if (assets.isEmpty) return const SizedBox.shrink();
      // Duplicate list so it wraps smoothly
      final items = [...assets, ...assets];

      return Container(
        height: 34,
        color: AppTheme.surface,
        child: Row(
          children: [
            // Static label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                border: Border(
                    right: BorderSide(color: AppTheme.cardBorder, width: 1)),
              ),
              height: 34,
              alignment: Alignment.center,
              child: Text(
                'LIVE',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.background,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                separatorBuilder: (_, __) => Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  color: AppTheme.divider,
                ),
                itemBuilder: (_, i) => _TickerItem(asset: items[i]),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _TickerItem extends StatelessWidget {
  final AssetModel asset;
  const _TickerItem({required this.asset});

  @override
  Widget build(BuildContext context) {
    final color =
        asset.isGain ? AppTheme.gainGreen : AppTheme.lossRed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          asset.symbol,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '\$${_fmt(asset.price)}',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${asset.isGain ? '▲' : '▼'}${asset.changePercent.abs().toStringAsFixed(2)}%',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _fmt(double p) {
    if (p > 1000) return p.toStringAsFixed(2);
    if (p > 1) return p.toStringAsFixed(2);
    return p.toStringAsFixed(4);
  }
}
