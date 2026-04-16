import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PriceAlert {
  final String symbol;
  final double targetPrice;
  final bool isAbove;

  PriceAlert({
    required this.symbol,
    required this.targetPrice,
    required this.isAbove,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'targetPrice': targetPrice,
    'isAbove': isAbove,
  };

  factory PriceAlert.fromJson(Map<String, dynamic> j) => PriceAlert(
    symbol: j['symbol'] as String,
    targetPrice: (j['targetPrice'] as num).toDouble(),
    isAbove: j['isAbove'] as bool,
  );

  @override
  bool operator ==(Object other) =>
      other is PriceAlert &&
          other.symbol == symbol &&
          other.targetPrice == targetPrice &&
          other.isAbove == isAbove;

  @override
  int get hashCode => Object.hash(symbol, targetPrice, isAbove);
}

const _kAlertsKey = 'price_alerts_v1';
const _kUiAlertsKey = 'ui_alerts_v1'; // mirrors AlertsScreen's key
const _kPollSeconds = 60;

const _foregroundChannelId = 'pulse_market_bg';
const _foregroundChannelName = 'Live Price Tracking';
const _alertChannelId = 'price_alerts';
const _alertChannelName = 'Price Alerts';

@pragma('vm:entry-point')
void onBgStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final localNotif = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotif.initialize(
      const InitializationSettings(android: androidInit));

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'Pulse Market',
      content: 'Tracking live prices…',
    );
  }

  service.on('stop').listen((_) => service.stopSelf());

  Timer.periodic(const Duration(seconds: _kPollSeconds), (_) async {
    await _pollAndAlert(service, localNotif);
  });

  await _pollAndAlert(service, localNotif);
}

Future<void> _pollAndAlert(
    ServiceInstance service,
    FlutterLocalNotificationsPlugin localNotif,
    ) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(_kAlertsKey) ?? [];
  final alerts = raw
      .map((s) => PriceAlert.fromJson(json.decode(s) as Map<String, dynamic>))
      .toList();

  if (alerts.isEmpty) return;

  final cryptoSymbols = alerts
      .map((a) => a.symbol.toUpperCase())
      .where((s) => _cgIds.containsKey(s))
      .toSet();

  if (cryptoSymbols.isEmpty) return;

  final ids = cryptoSymbols.map((s) => _cgIds[s]!).join(',');
  final url = Uri.parse(
      'https://api.coingecko.com/api/v3/simple/price?ids=$ids&vs_currencies=usd');

  try {
    final resp = await http.get(url).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return;

    final data = json.decode(resp.body) as Map<String, dynamic>;

    final prices = <String, double>{};
    for (final sym in cryptoSymbols) {
      final cgId = _cgIds[sym]!;
      final priceMap = data[cgId] as Map<String, dynamic>?;
      if (priceMap != null) {
        prices[sym] = (priceMap['usd'] as num).toDouble();
      }
    }

    if (service is AndroidServiceInstance) {
      final summary = prices.entries
          .map((e) => '${e.key}: \$${e.value.toStringAsFixed(2)}')
          .join('  •  ');
      service.setForegroundNotificationInfo(
        title: 'Pulse Market',
        content: summary,
      );
    }

    final alertsToRemove = <PriceAlert>[];
    for (final alert in alerts) {
      final price = prices[alert.symbol.toUpperCase()];
      if (price == null) continue;

      final triggered =
      alert.isAbove ? price >= alert.targetPrice : price <= alert.targetPrice;

      if (triggered) {
        final direction = alert.isAbove ? '▲ above' : '▼ below';
        await localNotif.show(
          alert.symbol.hashCode ^ alert.targetPrice.hashCode,
          '🔔 ${alert.symbol} Price Alert',
          '${alert.symbol} is $direction \$${alert.targetPrice.toStringAsFixed(2)}  (now \$${price.toStringAsFixed(2)})',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _alertChannelId,
              _alertChannelName,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
        alertsToRemove.add(alert);
      }
    }

    if (alertsToRemove.isNotEmpty) {
      // Remove triggered alerts from the background store
      alerts.removeWhere((a) => alertsToRemove.contains(a));
      await prefs.setStringList(
        _kAlertsKey,
        alerts.map((a) => json.encode(a.toJson())).toList(),
      );

      // FIX: Also mark triggered alerts as inactive in the UI store so the
      // AlertsScreen reflects reality after the app is reopened.
      final triggeredSymbols =
      alertsToRemove.map((a) => a.symbol.toUpperCase()).toSet();
      final uiRaw = prefs.getStringList(_kUiAlertsKey) ?? [];
      final updatedUi = uiRaw.map((s) {
        final decoded = json.decode(s) as Map<String, dynamic>;
        final sym = (decoded['symbol'] as String).toUpperCase();
        if (triggeredSymbols.contains(sym)) {
          decoded['isActive'] = false;
        }
        return json.encode(decoded);
      }).toList();
      await prefs.setStringList(_kUiAlertsKey, updatedUi);
    }
  } catch (_) {
    // Silently ignore network errors in background
  }
}

const _cgIds = {
  'BTC': 'bitcoin',
  'ETH': 'ethereum',
  'SOL': 'solana',
  'BNB': 'binancecoin',
};

class BackgroundPriceService {
  BackgroundPriceService._();

  static final _service = FlutterBackgroundService();

  /// Call this once from main() after runApp().
  static Future<void> initialize() async {
    final localNotif = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await localNotif.initialize(
        const InitializationSettings(android: androidInit));

    final androidPlugin = localNotif
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _foregroundChannelId,
        _foregroundChannelName,
        description: 'Keeps live market prices up to date.',
        importance: Importance.low,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _alertChannelId,
        _alertChannelName,
        description: 'Alerts when a price target is hit.',
        importance: Importance.high,
      ),
    );

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onBgStart,
        isForegroundMode: true,
        autoStart: true,
        notificationChannelId: _foregroundChannelId,
        initialNotificationTitle: 'Pulse Market',
        initialNotificationContent: 'Starting price tracking…',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onBgStart,
        onBackground: _iosBackground,
      ),
    );
  }

  static Future<void> start() async {
    final running = await _service.isRunning();
    if (!running) await _service.startService();
  }

  static Future<void> stop() async {
    _service.invoke('stop');
  }

  static Future<bool> isRunning() => _service.isRunning();

  static Future<void> addAlert(PriceAlert alert) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kAlertsKey) ?? [];

    final existing = raw
        .map((s) => PriceAlert.fromJson(json.decode(s) as Map<String, dynamic>))
        .toList();
    if (existing.contains(alert)) return;

    raw.add(json.encode(alert.toJson()));
    await prefs.setStringList(_kAlertsKey, raw);
  }

  static Future<List<PriceAlert>> getAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kAlertsKey) ?? [];
    return raw
        .map((s) =>
        PriceAlert.fromJson(json.decode(s) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> removeAlert(PriceAlert alert) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kAlertsKey) ?? [];
    final updated = raw.where((s) {
      final decoded =
      PriceAlert.fromJson(json.decode(s) as Map<String, dynamic>);
      return decoded != alert;
    }).toList();
    await prefs.setStringList(_kAlertsKey, updated);
  }
}

@pragma('vm:entry-point')
Future<bool> _iosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}