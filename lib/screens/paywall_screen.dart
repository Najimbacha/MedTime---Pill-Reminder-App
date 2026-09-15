import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../providers/subscription_provider.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('RoutineTime Premium'),
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Consumer<SubscriptionProvider>(
          builder: (context, subscription, _) {
            if (subscription.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final offerings = subscription.offerings;
            final hasRealOfferings =
                offerings != null && offerings.current != null;
            final monthly = hasRealOfferings
                ? offerings.current!.monthly
                : null;
            final lifetime = hasRealOfferings
                ? offerings.current!.lifetime
                : null;
            final selectedPackage = _selectedIndex == 0 ? lifetime : monthly;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        color: colorScheme.onTertiaryContainer,
                        size: 42,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Unlimited simple reminders',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create every routine you need while keeping the app calm, private, and focused.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onTertiaryContainer.withValues(
                            alpha: 0.75,
                          ),
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const _FeatureRow(
                  icon: Icons.all_inclusive_rounded,
                  title: 'Unlimited routines',
                  subtitle: 'No free-plan cap on recurring reminders.',
                ),
                const _FeatureRow(
                  icon: Icons.repeat_rounded,
                  title: 'Smart repeats',
                  subtitle: 'Weekdays, weekends, specific days, intervals.',
                ),
                const _FeatureRow(
                  icon: Icons.backup_outlined,
                  title: 'Secure backup',
                  subtitle:
                      'Keep routines and history available when you move phones.',
                ),
                const SizedBox(height: 18),
                _PricingCard(
                  title: 'Lifetime Access',
                  price: lifetime?.storeProduct.priceString ?? '\$30.00',
                  period: 'One-time',
                  subtitle: 'Unlimited routines forever',
                  isBestValue: true,
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                const SizedBox(height: 12),
                _PricingCard(
                  title: 'Monthly Plan',
                  price: monthly?.storeProduct.priceString ?? '\$1.99',
                  period: 'per month',
                  subtitle: 'Flexible access',
                  isSelected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                if (!hasRealOfferings) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Demo prices shown. Purchases become available from the store build.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () =>
                      _handlePurchase(context, subscription, selectedPackage),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Get Premium'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: subscription.restorePurchases,
                  child: const Text('Restore purchases'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handlePurchase(
    BuildContext context,
    SubscriptionProvider provider,
    Package? package,
  ) async {
    if (package == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Purchases are not available yet. Please try again from the store version.',
            ),
          ),
        );
      }
      return;
    }

    final success = await provider.purchasePackage(package);
    if (success && context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Premium is active')));
    }
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        tileColor: colorScheme.surfaceContainerLow,
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String subtitle;
  final bool isBestValue;
  final bool isSelected;
  final VoidCallback onTap;

  const _PricingCard({
    required this.title,
    required this.price,
    required this.period,
    required this.subtitle,
    this.isBestValue = false,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (isBestValue) ...[
                        const SizedBox(width: 8),
                        const _BestValuePill(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  period,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BestValuePill extends StatelessWidget {
  const _BestValuePill();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.tertiary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Best',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onTertiary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
