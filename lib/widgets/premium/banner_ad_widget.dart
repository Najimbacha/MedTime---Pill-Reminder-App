import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../providers/subscription_provider.dart';
import '../../services/ad_service.dart';
import '../../screens/paywall_screen.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAd();
  }

  void _loadAd() {
    final subscription = context.read<SubscriptionProvider>();
    if (subscription.isPremium || _isAdLoaded) return;

    _bannerAd = BannerAd(
      adUnitId: AdService.instance.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Banner Ad Loaded');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Banner Ad Failed to Load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscription, _) {
        if (subscription.isPremium) {
          return const SizedBox.shrink();
        }

        if (!_isAdLoaded || _bannerAd == null) {
          // Placeholder space while loading or failed - keeps layout stable
          // Or return SizedBox.shrink() if you prefer it to pop in
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "Remove Ads" Upsell Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                color: Colors.amber.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.stars_rounded,
                      size: 14,
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaywallScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Remove Ads with Premium',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // The Actual Ad
              SizedBox(
                height: _bannerAd!.size.height.toDouble(),
                width: _bannerAd!.size.width.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}
