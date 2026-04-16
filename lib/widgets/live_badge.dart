// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import '../theme.dart';
//
// /// Animated pulsing "LIVE" badge
// class LiveBadge extends StatefulWidget {
//   final bool compact;
//   const LiveBadge({super.key, this.compact = false});
//
//   @override
//   State<LiveBadge> createState() => _LiveBadgeState();
// }
//
// class _LiveBadgeState extends State<LiveBadge>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _ctrl;
//   late Animation<double> _pulse;
//
//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1200),
//     )..repeat(reverse: true);
//     _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
//       CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
//     );
//   }
//
//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _pulse,
//       builder: (_, __) => Container(
//         padding: EdgeInsets.symmetric(
//           horizontal: widget.compact ? 5 : 7,
//           vertical: widget.compact ? 2 : 4,
//         ),
//         decoration: BoxDecoration(
//           color: AppTheme.gainGreen.withOpacity(0.12),
//           borderRadius: BorderRadius.circular(6),
//           border: Border.all(
//             color: AppTheme.gainGreen.withOpacity(_pulse.value * 0.6),
//           ),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               width: widget.compact ? 5 : 6,
//               height: widget.compact ? 5 : 6,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: AppTheme.gainGreen.withOpacity(_pulse.value),
//               ),
//             ),
//             if (!widget.compact) ...[
//               const SizedBox(width: 4),
//               Text(
//                 'LIVE',
//                 style: GoogleFonts.spaceGrotesk(
//                   fontSize: 9,
//                   fontWeight: FontWeight.w800,
//                   color: AppTheme.gainGreen,
//                   letterSpacing: 0.5,
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }
