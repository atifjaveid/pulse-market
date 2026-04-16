// lib/widgets/price_alert_sheet.dart
//
// Bottom sheet that lets the user set a price alert for any asset.
// Usage:
//   showModalBottomSheet(
//     context: context,
//     builder: (_) => PriceAlertSheet(symbol: 'BTC', currentPrice: 70000),
//   );

import 'package:flutter/material.dart';
import '../services/background_services.dart';

class PriceAlertSheet extends StatefulWidget {
  final String symbol;
  final double currentPrice;

  const PriceAlertSheet({
    super.key,
    required this.symbol,
    required this.currentPrice,
  });

  @override
  State<PriceAlertSheet> createState() => _PriceAlertSheetState();
}

class _PriceAlertSheetState extends State<PriceAlertSheet> {
  final _controller = TextEditingController();
  bool _isAbove = true; // alert direction

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price')),
      );
      return;
    }

    await BackgroundPriceService.addAlert(PriceAlert(
      symbol: widget.symbol,
      targetPrice: value,
      isAbove: _isAbove,
    ));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Alert set: ${widget.symbol} ${_isAbove ? '▲ above' : '▼ below'} \$$value',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Price Alert — ${widget.symbol}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Current: \$${widget.currentPrice.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // Direction toggle
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('▲ Rises above')),
              ButtonSegment(value: false, label: Text('▼ Falls below')),
            ],
            selected: {_isAbove},
            onSelectionChanged: (s) => setState(() => _isAbove = s.first),
          ),
          const SizedBox(height: 16),

          // Target price input
          TextField(
            controller: _controller,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Target price (USD)',
              prefixText: '\$',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Set Alert'),
            ),
          ),
        ],
      ),
    );
  }
}