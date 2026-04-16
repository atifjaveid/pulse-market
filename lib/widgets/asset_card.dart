import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pulsemarket/widgets/sparklinr.dart';
import '../model/asset_model.dart';
import '../theme.dart';


class AssetCard extends StatelessWidget {
  final AssetModel asset;
  final VoidCallback onTap;

  const AssetCard({super.key, required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            // Logo
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              alignment: Alignment.center,
              child: Text(
                asset.logoEmoji.isEmpty ? asset.symbol[0] : asset.logoEmoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            // Name & Volume
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.symbol,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    asset.name,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Sparkline
            SizedBox(
              width: 60,
              height: 36,
              child: SparklineWidget(
                data: asset.sparklineData,
                color: asset.isGain ? AppTheme.gainGreen : AppTheme.lossRed,
                height: 36,
              ),
            ),
            const SizedBox(width: 12),
            // Price & Change
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${_formatPrice(asset.price)}',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: asset.isGain ? AppTheme.gainGreenGlow : AppTheme.lossRedGlow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${asset.isGain ? '+' : ''}${asset.changePercent.toStringAsFixed(2)}%',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: asset.isGain ? AppTheme.gainGreen : AppTheme.lossRed,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price > 1000) return price.toStringAsFixed(2);
    if (price > 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(4);
  }
}