import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Premium Mesh Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1A2E), // Deep Night Blue
                  Color(0xFF16213E), // Dark Blue
                  Color(0xFF321F28), // Deep Purple/Brown hint
                ],
              ),
            ),
          ),
          // Gradient Orbs (Pseudo-mesh effect)
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withOpacity(0.4), // Indigo
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEC4899).withOpacity(0.3), // Pink
              ),
            ),
          ),
          // Blur Overlay to soften orbs
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3), // Tint
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  backgroundBlendMode: BlendMode.overlay,
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black54],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Close Button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Premium Header
                        _buildPremiumHeader(),
                        const SizedBox(height: 32),

                        // Features List
                        _buildFeatureRow(
                          Icons.all_inclusive_rounded,
                          'Unlimited Medications',
                          'Track unlimited prescriptions with zero restrictions.',
                        ),
                        _buildFeatureRow(
                          Icons.family_restroom_rounded,
                          'Caregiver Access',
                          'Keep family in the loop with real-time monitoring.',
                        ),
                        _buildFeatureRow(
                          Icons.cloud_upload_rounded,
                          'Secure Cloud Backup',
                          'Never lose your history. Backup & Sync instantly.',
                        ),
                        _buildFeatureRow(
                          Icons.bar_chart_rounded,
                          'Advanced Analytics',
                          'Deep insights into adherence trends.',
                        ),

                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),

                // Pricing Section
                _buildPricingSection(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFD700), Color(0xFFB8860B)], // Gold Gradient
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Unlock MedTime Premium',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Join thousands of users managing their health with confidence.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.7),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFFFD700), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
        ),
      ),
      child: Consumer<SubscriptionProvider>(
        builder: (context, subscription, _) {
          if (subscription.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Annual Plan (Best Value)
              _PricingCard(
                title: 'Annual Plan',
                price: '\$29.99',
                period: '/ year',
                subtitle: 'Save 50% vs Monthly',
                isBestValue: true,
                isSelected: true, // Default selected
                onTap: () => _handlePurchase(context, subscription),
              ),
              const SizedBox(height: 12),

              // Monthly Plan
              _PricingCard(
                title: 'Monthly Plan',
                price: '\$4.99',
                period: '/ month',
                isSelected: false,
                onTap: () => _handlePurchase(context, subscription),
              ),

              const SizedBox(height: 24),

              // Footer Actions
              TextButton(
                onPressed: () => subscription.restorePurchases(),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                child: const Text(
                  'Restore Purchases',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              Text(
                'Secured by Google Play. Cancel anytime.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handlePurchase(
    BuildContext context,
    SubscriptionProvider provider,
  ) async {
    await provider.purchasePremium();
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome to Premium Club!'),
          backgroundColor: Color(0xFFFFD700),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? subtitle;
  final bool isBestValue;
  final bool isSelected;
  final VoidCallback onTap;

  const _PricingCard({
    required this.title,
    required this.price,
    required this.period,
    this.subtitle,
    this.isBestValue = false,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFFD700).withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              border: Border.all(
                color: isSelected ? const Color(0xFFFFD700) : Colors.white12,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                // Radio Indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFFD700)
                          : Colors.white38,
                      width: 2,
                    ),
                    color: isSelected
                        ? const Color(0xFFFFD700)
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.black)
                      : null,
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: Color(0xFF6366F1), // Indigo accent
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      period,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (isBestValue)
            Positioned(
              top: -10,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'BEST VALUE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
