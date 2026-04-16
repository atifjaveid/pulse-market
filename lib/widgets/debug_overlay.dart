import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/market_service.dart';
import '../theme.dart';

/// Tap the version chip to open a debug panel showing live API status.
/// Remove this widget (and its usages) before releasing to production.
class DebugOverlay extends StatefulWidget {
  const DebugOverlay({super.key});

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketService>(builder: (_, svc, __) {
      return Column(
        children: [
          // Small tap target
          // GestureDetector(
          //   onTap: () => setState(() => _open = !_open),
          //   child: Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          //     decoration: BoxDecoration(
          //       color: svc.error != null
          //           ? AppTheme.lossRed.withOpacity(0.2)
          //           : AppTheme.gainGreen.withOpacity(0.15),
          //       borderRadius: BorderRadius.circular(6),
          //       border: Border.all(
          //         color: svc.error != null
          //             ? AppTheme.lossRed.withOpacity(0.5)
          //             : AppTheme.gainGreen.withOpacity(0.4),
          //       ),
          //     ),
          //     child: Row(mainAxisSize: MainAxisSize.min, children: [
          //       Icon(
          //         svc.error != null
          //             ? Icons.error_outline_rounded
          //             : Icons.check_circle_outline_rounded,
          //         size: 11,
          //         color: svc.error != null
          //             ? AppTheme.lossRed
          //             : AppTheme.gainGreen,
          //       ),
          //       const SizedBox(width: 4),
          //       // Text(
          //       //   svc.error != null ? 'API Error' : 'API OK',
          //       //   style: GoogleFonts.spaceGrotesk(
          //       //       fontSize: 10,
          //       //       fontWeight: FontWeight.w600,
          //       //       color: svc.error != null
          //       //           ? AppTheme.lossRed
          //       //           : AppTheme.gainGreen),
          //       // ),
          //     ]),
          //   ),
          // ),

          // Expanded debug panel
          if (_open)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Loading', svc.isLoading.toString()),
                  _row('Assets loaded', '${svc.assets.length}'),
                  _row('Error', svc.error ?? 'none'),
                  const Divider(color: AppTheme.divider, height: 12),
                  Text('Live prices:',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 10, color: AppTheme.textMuted)),
                  const SizedBox(height: 4),
                  ...svc.assets.map((a) => _row(
                        a.symbol,
                        a.price > 0
                            ? '\$${a.price.toStringAsFixed(2)}'
                            : '— (no data)',
                      )),
                ],
              ),
            ),
        ],
      );
    });
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: [
          Text('$k: ',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 10, color: AppTheme.textMuted)),
          Expanded(
            child: Text(v,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}
