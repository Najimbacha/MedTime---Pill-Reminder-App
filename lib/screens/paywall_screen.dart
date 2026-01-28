import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../core/theme/app_colors.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Image or Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE3F2FD), Colors.white],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Close Button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.diamond_rounded, 
                            size: 60, 
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Title
                        const Text(
                          'Upgrade to Premium',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Unlock the full potential of MedTime and manage your health with ease.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Features List
                        _buildFeatureRow(Icons.all_inclusive_rounded, 'Unlimited Medications', 'Track as many medicines as you need.'),
                        _buildFeatureRow(Icons.family_restroom_rounded, 'Caregiver Access', 'Invite family members to monitor adherence.'),
                        _buildFeatureRow(Icons.cloud_upload_rounded, 'Cloud Backup', 'Securely backup and restore your data.'),
                        _buildFeatureRow(Icons.bar_chart_rounded, 'Advanced Reports', 'Detailed insights into your progress.'),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                
                // Bottom Section: Pricing & CTA
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Consumer<SubscriptionProvider>(
                    builder: (context, subscription, child) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (subscription.isLoading)
                            const CircularProgressIndicator()
                          else ...[
                            // Mock Pricing Options
                            _buildPricingOption(
                              context, 
                              title: 'Annual', 
                              price: '\$29.99 / year', 
                              subtext: 'Save 50%',
                              isSelected: true,
                              onTap: () => _handlePurchase(context, subscription),
                            ),
                            const SizedBox(height: 12),
                            _buildPricingOption(
                              context, 
                              title: 'Monthly', 
                              price: '\$4.99 / month',
                              isSelected: false,
                              onTap: () => _handlePurchase(context, subscription),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Restore Purchase
                            TextButton(
                              onPressed: () => subscription.restorePurchases(),
                              child: const Text(
                                'Restore Purchases',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 10),
                            const Text(
                              'Recurring billing. Cancel anytime.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _handlePurchase(BuildContext context, SubscriptionProvider provider) async {
    await provider.purchasePremium();
    if (context.mounted) {
      Navigator.pop(context); // Close paywall on success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome to Premium!')),
      );
    }
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingOption(BuildContext context, {
    required String title, 
    required String price, 
    String? subtext,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (subtext != null)
                    Text(
                      subtext,
                      style: TextStyle(
                        color: isSelected ? Colors.white.withOpacity(0.9) : AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              price,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
