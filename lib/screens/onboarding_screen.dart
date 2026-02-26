import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import 'main_screen.dart';

// ═══════════════════════════════════════════════════════
//  PREMIUM 2026 ONBOARDING — APPLE-INSPIRED
// ═══════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ── Animation Controllers ──
  late AnimationController _orbController;
  late AnimationController _heroController;
  late AnimationController _contentController;
  late AnimationController _shimmerController;

  // ── Hero animations ──
  late Animation<double> _heroFloat;
  late Animation<double> _heroScale;
  late Animation<double> _heroRotate;

  // ── Content stagger ──
  late Animation<double> _badgeFade;
  late Animation<Offset> _badgeSlide;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _featuresFade;
  late Animation<Offset> _featuresSlide;

  // Page data
  static const _pages = <_PageData>[
    _PageData(
      badge: 'WELCOME',
      title: 'Your health,\non autopilot.',
      subtitle:
          'Smart medication tracking that respects your privacy. Offline-first, zero friction.',
      asset: null, // app icon
      features: [
        _Feature(Icons.wifi_off_rounded, 'Works completely offline'),
        _Feature(Icons.fingerprint_rounded, 'Private & secure by design'),
        _Feature(Icons.bolt_rounded, 'Set up in under a minute'),
      ],
      orb1Color: Color(0xFF6366F1),
      orb2Color: Color(0xFF8B5CF6),
      orb3Color: Color(0xFF4F46E5),
    ),
    _PageData(
      badge: 'STEP 1',
      title: 'Add your\nmedicines.',
      subtitle:
          'Tap the + button, choose your medicine type, and set when you need to take it.',
      asset: 'assets/icons/medicine/3d/tablet.png',
      features: [
        _Feature(Icons.touch_app_rounded, 'Tap + to add a new medicine'),
        _Feature(Icons.category_rounded, 'Choose tablet, syrup, or injection'),
        _Feature(Icons.event_repeat_rounded, 'Set daily, weekly, or custom'),
      ],
      orb1Color: Color(0xFF10B981),
      orb2Color: Color(0xFF06B6D4),
      orb3Color: Color(0xFF059669),
    ),
    _PageData(
      badge: 'STEP 2',
      title: 'Never miss\na dose.',
      subtitle:
          'Your daily timeline shows every dose. Swipe to take or skip — we\'ll remind you on time.',
      asset: 'assets/icons/medicine/3d/injection.png',
      features: [
        _Feature(Icons.swipe_right_rounded, 'Swipe to mark as taken'),
        _Feature(Icons.circle, 'Color-coded status at a glance'),
        _Feature(
          Icons.notifications_active_rounded,
          'Precise reminders, always on time',
        ),
      ],
      orb1Color: Color(0xFF3B82F6),
      orb2Color: Color(0xFF6366F1),
      orb3Color: Color(0xFF2563EB),
    ),
    _PageData(
      badge: 'STEP 3',
      title: 'Stay safe,\nstay smart.',
      subtitle:
          'Drug interaction warnings, refill predictions, and AI-powered label scanning.',
      asset: 'assets/icons/medicine/3d/drop.png',
      features: [
        _Feature(Icons.shield_rounded, 'Drug interaction alerts'),
        _Feature(
          Icons.inventory_rounded,
          'Refill reminders before you run out',
        ),
        _Feature(
          Icons.document_scanner_rounded,
          'Scan medicine labels instantly',
        ),
      ],
      orb1Color: Color(0xFFF59E0B),
      orb2Color: Color(0xFFEF4444),
      orb3Color: Color(0xFFD97706),
    ),
    _PageData(
      badge: 'STEP 4',
      title: 'Care,\ntogether.',
      subtitle:
          'Share your progress with caregivers. Encrypted backup keeps your data safe.',
      asset: 'assets/icons/medicine/3d/liquid.png',
      features: [
        _Feature(Icons.people_rounded, 'Invite family as caregivers'),
        _Feature(Icons.cloud_done_rounded, 'Encrypted cloud backup'),
        _Feature(Icons.lock_rounded, 'Your data, your control'),
      ],
      orb1Color: Color(0xFFEC4899),
      orb2Color: Color(0xFF8B5CF6),
      orb3Color: Color(0xFFDB2777),
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    // Orb ambient pulse — slow, continuous
    _orbController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);

    // Hero float/breathe — continuous
    _heroController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    )..repeat(reverse: true);

    _heroFloat = Tween<double>(begin: 0, end: -22).animate(
      CurvedAnimation(parent: _heroController, curve: Curves.easeInOutSine),
    );
    _heroScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _heroController, curve: Curves.easeInOutSine),
    );
    _heroRotate = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _heroController, curve: Curves.easeInOutSine),
    );

    // Shimmer effect
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    // Content stagger — plays on each page change
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    _buildContentAnimations();
    _contentController.forward();
  }

  void _buildContentAnimations() {
    // Badge
    _badgeFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );
    _badgeSlide = Tween<Offset>(begin: const Offset(0, 12), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _contentController,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
          ),
        );
    // Title
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.1, 0.45, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 30), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _contentController,
            curve: const Interval(0.1, 0.5, curve: Curves.easeOutCubic),
          ),
        );
    // Subtitle
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.25, 0.6, curve: Curves.easeOut),
      ),
    );
    _subtitleSlide = Tween<Offset>(begin: const Offset(0, 25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _contentController,
            curve: const Interval(0.25, 0.65, curve: Curves.easeOutCubic),
          ),
        );
    // Features
    _featuresFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
      ),
    );
    _featuresSlide = Tween<Offset>(begin: const Offset(0, 20), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _contentController,
            curve: const Interval(0.45, 0.9, curve: Curves.easeOutCubic),
          ),
        );
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _contentController.reset();
    _contentController.forward();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _heroController.dispose();
    _contentController.dispose();
    _shimmerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: Stack(
        children: [
          // ━━ Layer 0: Deep background ━━
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.3),
                radius: 1.2,
                colors: [Color(0xFF0F172A), Color(0xFF030712)],
              ),
            ),
          ),

          // ━━ Layer 1: Ambient Orbs ━━
          AnimatedBuilder(
            animation: _orbController,
            builder: (context, _) => CustomPaint(
              painter: _AmbientOrbPainter(
                progress: _orbController.value,
                color1: page.orb1Color,
                color2: page.orb2Color,
                color3: page.orb3Color,
                size: size,
              ),
              size: size,
            ),
          ),

          // ━━ Layer 2: Noise texture overlay ━━
          Opacity(opacity: 0.03, child: Container(color: Colors.white)),

          // ━━ Layer 3: Page content ━━
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return _buildPage(context, _pages[index], size);
            },
          ),

          // ━━ Layer 4: Bottom controls ━━
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(context, size),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context, _PageData page, Size screenSize) {
    return AnimatedBuilder(
      animation: _contentController,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              SizedBox(height: screenSize.height * 0.10),

              // ── Hero Asset ──
              SizedBox(
                height: screenSize.height * 0.35,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _heroController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _heroFloat.value),
                        child: Transform.scale(
                          scale: _heroScale.value,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..rotateZ(_heroRotate.value),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: _buildHeroAsset(page, screenSize),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── Badge ──
              Opacity(
                opacity: _badgeFade.value,
                child: Transform.translate(
                  offset: _badgeSlide.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: page.orb1Color.withValues(alpha: 0.15),
                      border: Border.all(
                        color: page.orb1Color.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      page.badge,
                      style: TextStyle(
                        color: page.orb1Color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Title ──
              Opacity(
                opacity: _titleFade.value,
                child: Transform.translate(
                  offset: _titleSlide.value,
                  child: Text(
                    page.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      height: 1.08,
                      letterSpacing: -1.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Subtitle ──
              Opacity(
                opacity: _subtitleFade.value,
                child: Transform.translate(
                  offset: _subtitleSlide.value,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      page.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.55,
                        letterSpacing: -0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Feature Chips ──
              Opacity(
                opacity: _featuresFade.value,
                child: Transform.translate(
                  offset: _featuresSlide.value,
                  child: Column(
                    children: page.features.map((f) {
                      return _FeatureRow(
                        feature: f,
                        accentColor: page.orb1Color,
                      );
                    }).toList(),
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        );
      },
    );
  }

  // ── Hero asset with dramatic glow ──
  Widget _buildHeroAsset(_PageData page, Size screenSize) {
    final isIcon = page.asset == null;
    final assetSize = isIcon ? 180.0 : 170.0;

    return SizedBox(
      width: assetSize + 100,
      height: assetSize + 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow Orbs (Static)
          Container(
            width: assetSize + 40,
            height: assetSize + 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: page.orb1Color.withValues(alpha: 0.4),
                  blurRadius: 80,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

          // The Asset with Shimmer sweep
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment(
                      -2.0 + 4.0 * _shimmerController.value,
                      -0.5,
                    ),
                    end: Alignment(-1.0 + 4.0 * _shimmerController.value, 0.5),
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.4),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(bounds);
                },
                child: child,
              );
            },
            child: Image.asset(
              page.asset ?? 'assets/appicon.png',
              width: assetSize,
              height: assetSize,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Bar: glass + indicators + CTA ──
  Widget _buildBottomBar(BuildContext context, Size screenSize) {
    final isLast = _currentPage == _pages.length - 1;
    final page = _pages[_currentPage];
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          padding: EdgeInsets.fromLTRB(32, 20, 32, bottomPad + 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF030712).withValues(alpha: 0.0),
                const Color(0xFF030712).withValues(alpha: 0.85),
                const Color(0xFF030712),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Liquid dot indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 5,
                    width: active ? 32 : 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: active
                          ? page.orb1Color
                          : Colors.white.withValues(alpha: 0.15),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: page.orb1Color.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // CTA Button
              Row(
                children: [
                  if (!isLast)
                    GestureDetector(
                      onTap: () => _completeOnboarding(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 8,
                        ),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (!isLast) const Spacer(),
                  Expanded(
                    flex: isLast ? 1 : 0,
                    child: GestureDetector(
                      onTap: () {
                        if (isLast) {
                          _completeOnboarding(context);
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutQuart,
                          );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        height: 58,
                        width: isLast ? screenSize.width - 64 : 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(29),
                          gradient: LinearGradient(
                            colors: [page.orb1Color, page.orb2Color],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: page.orb1Color.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: isLast
                              ? MainAxisSize.max
                              : MainAxisSize.min,
                          children: [
                            Text(
                              isLast ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLast
                                  ? Icons.arrow_forward_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeOnboarding(BuildContext context) async {
    final notificationService = NotificationService.instance;
    await notificationService.requestAllPermissions();

    if (context.mounted) {
      context.read<SettingsService>().setOnboardingCompleted(true);
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════
//  FEATURE ROW
// ═══════════════════════════════════════════════════════

class _FeatureRow extends StatelessWidget {
  final _Feature feature;
  final Color accentColor;

  const _FeatureRow({required this.feature, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: accentColor.withValues(alpha: 0.12),
            ),
            child: Icon(feature.icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              feature.text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  AMBIENT ORB PAINTER
// ═══════════════════════════════════════════════════════

class _AmbientOrbPainter extends CustomPainter {
  final double progress;
  final Color color1, color2, color3;
  final Size size;

  _AmbientOrbPainter({
    required this.progress,
    required this.color1,
    required this.color2,
    required this.color3,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final w = canvasSize.width;
    final h = canvasSize.height;

    // Orb 1 — large, upper right
    _drawOrb(
      canvas,
      Offset(
        w * 0.75 + math.sin(progress * math.pi * 2) * 40,
        h * 0.18 + math.cos(progress * math.pi * 2) * 30,
      ),
      w * 0.55,
      color1,
      0.12 + 0.04 * math.sin(progress * math.pi * 2),
    );

    // Orb 2 — medium, left
    _drawOrb(
      canvas,
      Offset(
        w * 0.15 + math.cos(progress * math.pi * 2 + 1) * 35,
        h * 0.35 + math.sin(progress * math.pi * 2 + 1) * 25,
      ),
      w * 0.45,
      color2,
      0.09 + 0.03 * math.cos(progress * math.pi * 2 + 1),
    );

    // Orb 3 — subtle, bottom center
    _drawOrb(
      canvas,
      Offset(
        w * 0.5 + math.sin(progress * math.pi * 2 + 2.5) * 30,
        h * 0.55 + math.cos(progress * math.pi * 2 + 2.5) * 20,
      ),
      w * 0.50,
      color3,
      0.06 + 0.02 * math.sin(progress * math.pi * 2 + 2.5),
    );
  }

  void _drawOrb(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: opacity * 0.3),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_AmbientOrbPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color1 != color1 ||
      oldDelegate.color2 != color2 ||
      oldDelegate.color3 != color3;
}

// ═══════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════

class _PageData {
  final String badge;
  final String title;
  final String subtitle;
  final String? asset;
  final List<_Feature> features;
  final Color orb1Color;
  final Color orb2Color;
  final Color orb3Color;

  const _PageData({
    required this.badge,
    required this.title,
    required this.subtitle,
    this.asset,
    required this.features,
    required this.orb1Color,
    required this.orb2Color,
    required this.orb3Color,
  });
}

class _Feature {
  final IconData icon;
  final String text;

  const _Feature(this.icon, this.text);
}
