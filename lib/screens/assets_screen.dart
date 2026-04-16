
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/asset_model.dart';
import '../services/background_services.dart';
import '../services/market_service.dart';
import '../theme.dart';

class AlertsScreen extends StatefulWidget {
  final AssetModel? preselectedAsset;
  const AlertsScreen({super.key, this.preselectedAsset});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  // ── Persistence key (UI-level alerts) ─────────────────────────────────────
  static const _kUiAlertsKey = 'ui_alerts_v1';

  final List<_AlertItem> _alerts = [];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadAlerts().then((_) {
      if (widget.preselectedAsset != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAddAlertSheet(context, prefill: widget.preselectedAsset);
        });
      }
    });
  }



  Future<void> _loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kUiAlertsKey) ?? [];
    if (!mounted) return;
    setState(() {
      _alerts.clear();
      _alerts.addAll(
        raw.map((s) => _AlertItem.fromJson(json.decode(s) as Map<String, dynamic>)),
      );
    });

    // Re-sync all active alerts to background service on every load.
    // This re-populates price_alerts_v1 after the app is killed and restarted.
    for (final alert in _alerts) {
      await _syncAlertToBackground(alert);
    }
  }

  Future<void> _saveAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kUiAlertsKey,
      _alerts.map((a) => json.encode(a.toJson())).toList(),
    );
  }

  // ── Background-service sync ────────────────────────────────────────────────
  // Each UI range alert maps to two BackgroundPriceService alerts:
  //   • price falls BELOW minPrice  → isAbove: false
  //   • price rises ABOVE maxPrice  → isAbove: true

  Future<void> _syncAlertToBackground(_AlertItem item, {bool remove = false}) async {
    final bgAlertMin = PriceAlert(
      symbol: item.symbol,
      targetPrice: item.minPrice,
      isAbove: false,
    );
    final bgAlertMax = PriceAlert(
      symbol: item.symbol,
      targetPrice: item.maxPrice,
      isAbove: true,
    );

    if (remove) {
      await BackgroundPriceService.removeAlert(bgAlertMin);
      await BackgroundPriceService.removeAlert(bgAlertMax);
    } else {
      // Remove stale copies first to avoid duplicates on edit
      await BackgroundPriceService.removeAlert(bgAlertMin);
      await BackgroundPriceService.removeAlert(bgAlertMax);
      if (item.isActive) {
        await BackgroundPriceService.addAlert(bgAlertMin);
        await BackgroundPriceService.addAlert(bgAlertMax);
      }
    }
  }

  // ── Price helpers ──────────────────────────────────────────────────────────

  bool _isBreached(_AlertItem alert, List<AssetModel> assets) {
    final asset = assets.firstWhere(
          (a) => a.symbol == alert.symbol,
      orElse: _nullAsset,
    );
    if (asset.price == 0 || !alert.isActive) return false;
    return asset.price < alert.minPrice || asset.price > alert.maxPrice;
  }

  static AssetModel _nullAsset() => const AssetModel(
    symbol: '',
    name: '',
    type: 'stock',
    price: 0,
    change: 0,
    changePercent: 0,
    high24h: 0,
    low24h: 0,
    volume: 0,
    marketCap: 0,
    logoEmoji: '',
    sparklineData: [],
    color: '',
  );

  double _livePrice(String symbol, List<AssetModel> assets) {
    return assets
        .firstWhere((a) => a.symbol == symbol, orElse: _nullAsset)
        .price;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketService>(builder: (context, svc, _) {
      final assets = svc.assets;
      final activeCount = _alerts.where((a) => a.isActive).length;
      final breachedCount =
          _alerts.where((a) => _isBreached(a, assets)).length;

      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(activeCount, breachedCount),
              const SizedBox(height: 8),
              _buildSummaryRow(),
              const SizedBox(height: 8),
              Expanded(
                child: _alerts.isEmpty
                    ? _buildEmpty()
                    : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _alerts.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      _alertCard(_alerts[i], i, assets),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddAlertSheet(context),
          backgroundColor: AppTheme.accent,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'New Alert',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      );
    });
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(int activeCount, int breachedCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Text(
              'Price Alerts',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (breachedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.lossRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.lossRed.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppTheme.lossRed, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '$breachedCount Breached',
                          style: GoogleFonts.spaceGrotesk(
                              color: AppTheme.lossRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_active_rounded,
                          color: AppTheme.accent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$activeCount Active',
                        style: GoogleFonts.spaceGrotesk(
                            color: AppTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        'Alerts trigger when live price goes outside your set range.',
        style: GoogleFonts.spaceGrotesk(
            color: AppTheme.textSecondary, fontSize: 13),
      ),
    );
  }

  // ── Alert card ─────────────────────────────────────────────────────────────

  Widget _alertCard(
      _AlertItem alert, int index, List<AssetModel> assets) {
    final live = _livePrice(alert.symbol, assets);
    final breached = _isBreached(alert, assets);
    final inRange = live > 0 &&
        live >= alert.minPrice &&
        live <= alert.maxPrice;

    double markerPos = 0.5;
    if (alert.maxPrice > alert.minPrice && live > 0) {
      markerPos = ((live - alert.minPrice) /
          (alert.maxPrice - alert.minPrice))
          .clamp(0.0, 1.0);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: breached
              ? AppTheme.lossRed.withOpacity(0.5)
              : alert.isActive
              ? AppTheme.accent.withOpacity(0.3)
              : AppTheme.cardBorder,
        ),
        boxShadow: breached
            ? [
          BoxShadow(
            color: AppTheme.lossRed.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 1,
          )
        ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      alert.emoji.isEmpty
                          ? alert.symbol[0]
                          : alert.emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            alert.symbol,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (breached) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.lossRed.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'BREACHED',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.lossRed,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (live > 0)
                        Text(
                          'Live: \$${_fmt(live)}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: inRange
                                ? AppTheme.gainGreen
                                : AppTheme.lossRed,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Text(alert.name,
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _showAddAlertSheet(context,
                        existing: alert, existingIndex: index),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_rounded,
                          color: AppTheme.textSecondary, size: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ── FIX: toggle syncs to background service ───────────────
                  Switch(
                    value: alert.isActive,
                    onChanged: (v) async {
                      final updated = alert.copyWith(isActive: v);
                      setState(() => _alerts[index] = updated);
                      await _saveAlerts();
                      await _syncAlertToBackground(updated);
                    },
                    activeColor: AppTheme.accent,
                    inactiveTrackColor: AppTheme.surface,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRangeBar(markerPos, live > 0),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _rangeLabel(
                  'Min', '\$${_fmt(alert.minPrice)}', AppTheme.lossRed),
              if (live > 0 && inRange)
                Text(
                  'In range ✓',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      color: AppTheme.gainGreen,
                      fontWeight: FontWeight.w600),
                ),
              _rangeLabel(
                  'Max', '\$${_fmt(alert.maxPrice)}', AppTheme.gainGreen),
            ],
          ),
        ],
      ),
    );
  }

  // ── Range bar ──────────────────────────────────────────────────────────────

  Widget _buildRangeBar(double markerPos, bool showMarker) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 6,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.lossRed,
                  AppTheme.warningOrange,
                  AppTheme.gainGreen
                ],
              ),
            ),
          ),
        ),
        if (showMarker)
          Positioned(
            left: 0,
            right: 0,
            top: -5,
            child: FractionallySizedBox(
              widthFactor: markerPos,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 4)
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _rangeLabel(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.spaceGrotesk(
                    color: AppTheme.textMuted, fontSize: 10)),
          ],
        ),
        Text(value,
            style: GoogleFonts.outfit(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: const Icon(Icons.notifications_none_rounded,
                color: AppTheme.textMuted, size: 36),
          ),
          const SizedBox(height: 16),
          Text('No alerts yet',
              style: GoogleFonts.outfit(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Tap + to create your first price alert',
              style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Add / Edit sheet ───────────────────────────────────────────────────────

  void _showAddAlertSheet(BuildContext context,
      {AssetModel? prefill, _AlertItem? existing, int? existingIndex}) {
    final svc = context.read<MarketService>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddAlertSheet(
        prefill: prefill,
        existing: existing,
        availableSymbols: svc.assets.map((a) => a.symbol).toList(),
        onSave: (item) async {
          if (existingIndex != null) {
            await _syncAlertToBackground(_alerts[existingIndex], remove: true);
          }
          setState(() {
            if (existingIndex != null) {
              _alerts[existingIndex] = item;
            } else {
              _alerts.add(item);
            }
          });
          await _saveAlerts();
          await _syncAlertToBackground(item);
        },
        onDelete: existingIndex != null
            ? () async {
                await _syncAlertToBackground(_alerts[existingIndex], remove: true);
                setState(() => _alerts.removeAt(existingIndex));
                await _saveAlerts();
              }
            : null,
      ),
    );
  }

  String _fmt(double v) {
    if (v > 1000) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}

// ── Add/Edit Alert Bottom Sheet ───────────────────────────────────────────────

class _AddAlertSheet extends StatefulWidget {
  final AssetModel? prefill;
  final _AlertItem? existing;
  final List<String> availableSymbols;
  final Function(_AlertItem) onSave;
  final Function()? onDelete;

  const _AddAlertSheet({
    this.prefill,
    this.existing,
    required this.availableSymbols,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_AddAlertSheet> createState() => _AddAlertSheetState();
}

class _AddAlertSheetState extends State<_AddAlertSheet> {
  late TextEditingController _symbolCtrl;
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;
  String? _selectedSymbol;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final p = widget.prefill;

    _selectedSymbol = e?.symbol ?? p?.symbol;
    _symbolCtrl = TextEditingController(text: _selectedSymbol ?? '');
    _minCtrl = TextEditingController(
        text: e != null
            ? e.minPrice.toStringAsFixed(0)
            : p != null
            ? (p.price * 0.9).toStringAsFixed(0)
            : '');
    _maxCtrl = TextEditingController(
        text: e != null
            ? e.maxPrice.toStringAsFixed(0)
            : p != null
            ? (p.price * 1.1).toStringAsFixed(0)
            : '');
  }

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.existing != null ? 'Edit Alert' : 'Create Price Alert',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _label('Asset Symbol'),
          const SizedBox(height: 8),
          if (widget.availableSymbols.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.availableSymbols.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final sym = widget.availableSymbols[i];
                  final isSelected = _selectedSymbol == sym;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedSymbol = sym;
                      _symbolCtrl.text = sym;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                        isSelected ? AppTheme.accent : AppTheme.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accent
                              : AppTheme.cardBorder,
                        ),
                      ),
                      child: Text(
                        sym,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            _textField(_symbolCtrl, 'e.g. BTC, ETH, AAPL'),
          const SizedBox(height: 20),
          _label('Price Range'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.arrow_downward_rounded,
                          color: AppTheme.lossRed, size: 14),
                      const SizedBox(width: 4),
                      Text('Min Price',
                          style: GoogleFonts.spaceGrotesk(
                              color: AppTheme.lossRed, fontSize: 12)),
                    ]),
                    const SizedBox(height: 6),
                    _textField(_minCtrl, '0.00',
                        prefix: '\$', borderColor: AppTheme.lossRed),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.arrow_upward_rounded,
                          color: AppTheme.gainGreen, size: 14),
                      const SizedBox(width: 4),
                      Text('Max Price',
                          style: GoogleFonts.spaceGrotesk(
                              color: AppTheme.gainGreen, fontSize: 12)),
                    ]),
                    const SizedBox(height: 6),
                    _textField(_maxCtrl, '0.00',
                        prefix: '\$', borderColor: AppTheme.gainGreen),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border:
              Border.all(color: AppTheme.accent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppTheme.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Alert triggers when live price goes outside this range.',
                    style: GoogleFonts.spaceGrotesk(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              // ── FIX: async so we can await onSave (which persists + syncs)
              onPressed: () async {
                final sym =
                (_selectedSymbol ?? _symbolCtrl.text).toUpperCase().trim();
                if (sym.isEmpty) return;
                final minVal = double.tryParse(_minCtrl.text) ?? 0;
                final maxVal = double.tryParse(_maxCtrl.text) ?? 0;
                if (minVal <= 0 || maxVal <= 0 || minVal >= maxVal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Enter a valid range: Min must be less than Max and both > 0'),
                    ),
                  );
                  return;
                }
                final item = _AlertItem(
                  sym,
                  sym,
                  minVal,
                  maxVal,
                  true,
                  '',
                );
                await widget.onSave(item);
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                widget.existing != null ? 'Update Alert' : 'Create Alert',
                style: GoogleFonts.outfit(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (widget.onDelete != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: TextButton(
                onPressed: () async {
                  await widget.onDelete!();
                  if (context.mounted) Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.lossRed,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Delete Alert',
                  style: GoogleFonts.outfit(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: GoogleFonts.spaceGrotesk(
          color: AppTheme.textSecondary, fontSize: 13));

  Widget _textField(TextEditingController ctrl, String hint,
      {String? prefix, Color? borderColor}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: borderColor?.withOpacity(0.4) ?? AppTheme.cardBorder),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(
              color: AppTheme.textMuted, fontSize: 14),
          prefixText: prefix,
          prefixStyle:
          GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 15),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

// ── Alert data model ──────────────────────────────────────────────────────────

class _AlertItem {
  final String symbol;
  final String name;
  final double minPrice;
  final double maxPrice;
  final bool isActive;
  final String emoji;

  const _AlertItem(this.symbol, this.name, this.minPrice, this.maxPrice,
      this.isActive, this.emoji);

  _AlertItem copyWith({bool? isActive}) => _AlertItem(
      symbol, name, minPrice, maxPrice, isActive ?? this.isActive, emoji);

  // ── Persistence ─────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'minPrice': minPrice,
    'maxPrice': maxPrice,
    'isActive': isActive,
    'emoji': emoji,
  };

  factory _AlertItem.fromJson(Map<String, dynamic> j) => _AlertItem(
    j['symbol'] as String,
    j['name'] as String,
    (j['minPrice'] as num).toDouble(),
    (j['maxPrice'] as num).toDouble(),
    j['isActive'] as bool,
    (j['emoji'] as String?) ?? '',
  );
}