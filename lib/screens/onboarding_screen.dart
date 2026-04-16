import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'main_scaffold.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _floatController;

  final List<OnboardingPage> _pages = [
    const OnboardingPage(
      icon: '📈',
      title: 'Live Market\nData',
      subtitle: 'Real-time prices for thousands of stocks and cryptocurrencies, updated every second.',
      primaryColor: AppTheme.primary,
      chartType: ChartType.line,
    ),
    const OnboardingPage(
      icon: '🕯️',
      title: 'Candle Charts\n& Deep Analysis',
      subtitle: 'Professional-grade candlestick charts with technical indicators and historical data.',
      primaryColor: AppTheme.accent,
      chartType: ChartType.candle,
    ),
    const OnboardingPage(
      icon: '🔔',
      title: 'Smart Price\nAlerts',
      subtitle: 'Set custom min/max price ranges and get instant push notifications when markets move.',
      primaryColor: AppTheme.gainGreen,
      chartType: ChartType.alert,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
  }

  void _goNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _markOnboardingComplete();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainScaffold(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: TextButton(
                  onPressed: () {
                    _markOnboardingComplete();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const MainScaffold()),
                    );
                  },
                  child: Text(
                    'Skip',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _buildPage(_pages[i]),
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          AnimatedBuilder(
            animation: _floatController,
            builder: (_, __) {
              final offset = (_floatController.value - 0.5) * 16;
              return Transform.translate(
                offset: Offset(0, offset),
                child: _buildIllustration(page),
              );
            },
          ),
          const SizedBox(height: 48),
          // Text
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration(OnboardingPage page) {
    return Container(
      width: 260,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: page.primaryColor.withOpacity(0.15),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CustomPaint(
          painter: OnboardingIllustrationPainter(
            chartType: page.chartType,
            color: page.primaryColor,
          ),
          child: Center(
            child: Text(
              page.icon,
              style: const TextStyle(fontSize: 52),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final page = _pages[_currentPage];
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 40),
      child: Column(
        children: [
          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isActive ? page.primaryColor : AppTheme.textMuted,
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          // CTA Button
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _goNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: page.primaryColor,
                foregroundColor: AppTheme.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Continue',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _currentPage == _pages.length - 1
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum ChartType { line, candle, alert }

class OnboardingPage {
  final String icon;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final ChartType chartType;

  const OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.chartType,
  });
}

class OnboardingIllustrationPainter extends CustomPainter {
  final ChartType chartType;
  final Color color;

  OnboardingIllustrationPainter({required this.chartType, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    switch (chartType) {
      case ChartType.line:
        _drawLineBg(canvas, size);
        break;
      case ChartType.candle:
        _drawCandleBg(canvas, size);
        break;
      case ChartType.alert:
        _drawAlertBg(canvas, size);
        break;
    }
  }

  void _drawLineBg(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final points = [
      Offset(0, size.height * 0.7),
      Offset(size.width * 0.15, size.height * 0.65),
      Offset(size.width * 0.3, size.height * 0.55),
      Offset(size.width * 0.4, size.height * 0.6),
      Offset(size.width * 0.55, size.height * 0.4),
      Offset(size.width * 0.7, size.height * 0.35),
      Offset(size.width * 0.85, size.height * 0.25),
      Offset(size.width, size.height * 0.2),
    ];

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (final p in points.skip(1)) path.lineTo(p.dx, p.dy);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(path, paint..color = color.withOpacity(0.5)..strokeWidth = 1.5);
  }

  void _drawCandleBg(Canvas canvas, Size size) {
    final colors = [color, Colors.red.withOpacity(0.6), color, color, Colors.red.withOpacity(0.6), color];
    final rects = [0.1, 0.25, 0.4, 0.55, 0.7, 0.85];
    for (int i = 0; i < rects.length; i++) {
      final x = size.width * rects[i];
      final h = size.height * (0.2 + (i % 3) * 0.1);
      final top = size.height * (0.3 + (i % 2) * 0.1);
      canvas.drawRect(
        Rect.fromLTWH(x, top, size.width * 0.06, h),
        Paint()..color = colors[i].withOpacity(0.3),
      );
    }
  }

  void _drawAlertBg(Canvas canvas, Size size) {
    final dashPaint = Paint()
      ..color = AppTheme.warningOrange.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    // Draw two dashed horizontal lines
    for (final y in [size.height * 0.3, size.height * 0.7]) {
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(x + 12, y), dashPaint);
        x += 20;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}