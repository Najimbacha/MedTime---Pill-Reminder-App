import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/medicine_provider.dart';
import '../models/medicine.dart';
import '../widgets/empty_state_widget.dart';
import 'add_edit_medicine_screen.dart';
import '../providers/subscription_provider.dart';
import '../providers/schedule_provider.dart'; // Add this imports
import 'paywall_screen.dart';

class CabinetScreen extends StatelessWidget {
  const CabinetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Medicine Cabinet',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 28,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: const [],
      ),
      body: Consumer<MedicineProvider>(
        builder: (context, provider, child) {
          final medicines = provider.medicines;
          
          if (medicines.isEmpty) {
            return Center(
              child: EmptyStateWidget(
                imageAsset: 'assets/icons/medicine/check_badge.png',
                title: 'Cabinet Empty',
                message: 'Add your medicines to track inventory',
                buttonText: 'Add First Medicine',
                onButtonPressed: () => _navigateToAddMedicine(context),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: medicines.length,
            itemBuilder: (context, index) {
              final medicine = medicines[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AppleMedicineCard(
                  medicine: medicine,
                  isDark: isDark,
                  onTap: () => _navigateToAddMedicine(context, medicine: medicine),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70), // Lift above Glass Nav Bar
        child: FloatingActionButton.extended(
          onPressed: () => _navigateToAddMedicine(context),
          backgroundColor: Theme.of(context).primaryColor,
          elevation: 6,
          highlightElevation: 10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          label: const Text(
            'Add Medicine',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }


  void _navigateToAddMedicine(BuildContext context, {Medicine? medicine}) async {
    // If editing (medicine != null), allow access always
    if (medicine != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddEditMedicineScreen(medicine: medicine),
        ),
      );
      return;
    }

    // Adding new medicine: Check limits
    final subscription = context.read<SubscriptionProvider>();
    final medicineProvider = context.read<MedicineProvider>();
    
    if (!subscription.isPremium && medicineProvider.medicines.length >= 3) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      // If still not premium after paywall, stop
      if (!subscription.isPremium) return;
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AddEditMedicineScreen(),
        ),
      );
    }
  }
}

/// Apple-style medicine card with rich info display
class _AppleMedicineCard extends StatelessWidget {
  final Medicine medicine;
  final bool isDark;
  final VoidCallback onTap;

  const _AppleMedicineCard({
    required this.medicine,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = medicine.colorValue;
    final isLow = medicine.isLowStock;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12), // Reduced from 16
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.white.withOpacity(0.06) 
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark 
                ? Colors.white.withOpacity(0.08) 
                : Colors.black.withOpacity(0.04),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 3D Medicine Icon
            Container(
              width: 58, 
              height: 58,
              padding: const EdgeInsets.all(4), 
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.indigo.withOpacity(0.06),
                  width: 1,
                ),
              ),
              child: Image.asset(
                _get3DAssetPath(medicine.typeIcon), // Use new 3D mapping
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                    // Fallback to original if 3D missing
                    return Image.asset(medicine.iconAssetPath); 
                },
              ),
            ),
            const SizedBox(width: 14),
            
            // Medicine Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          medicine.name,
                          style: TextStyle(
                            fontSize: 16, // Slightly smaller for density
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLow)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LOW STOCK',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Info Row: Dosage + Stock info
                  Row(
                    children: [
                      // Dosage chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withOpacity(0.1), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTypeIcon(medicine.typeIcon),
                              size: 11,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              medicine.dosage,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Stock status & Prediction
                      Builder(
                        builder: (context) {
                          // Get prediction
                          final scheduleProvider = context.watch<ScheduleProvider>();
                          final refillDate = scheduleProvider.getEstimatedRefillDate(
                            medicine.id!, 
                            medicine.currentStock
                          );

                          String stockText = '${medicine.currentStock} left';
                          Color stockColor = isDark ? Colors.white38 : Colors.grey.shade500;
                          
                          if (refillDate != null) {
                            final daysUntil = refillDate.difference(DateTime.now()).inDays;
                            
                            if (daysUntil <= 0) {
                              stockText = 'Refill Needed Today';
                              stockColor = Colors.red;
                            } else if (daysUntil < 7) {
                              stockText = 'Empty by ${_getWeekday(refillDate)}'; // "Empty by Tue"
                              stockColor = Colors.orange.shade700;
                            } else if (daysUntil < 30) {
                              stockText = 'Lasts until ${_getMonthDay(refillDate)}'; // "Lasts until Feb 12"
                              stockColor = isDark ? Colors.white60 : Colors.grey.shade700;
                            }
                          } else if (isLow) {
                             stockText = '${medicine.currentStock} left (Low)';
                             stockColor = Colors.red;
                          }

                          return Text(
                            stockText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: (refillDate != null && refillDate.difference(DateTime.now()).inDays < 7) || isLow
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: stockColor,
                            ),
                          );
                        }
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• ${_getTypeName(medicine.typeIcon)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
  
  String _getWeekday(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
  
  String _getMonthDay(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  IconData _getTypeIcon(int typeIcon) {
    switch (typeIcon) {
      case 1: return Icons.medication_rounded;
      case 2: return Icons.liquor_rounded; // Syrup
      case 3: return Icons.vaccines_rounded;
      case 4: return Icons.water_drop_rounded; // Drops/Bottle
      default: return Icons.medication_rounded;
    }
  }

  String _getTypeName(int typeIcon) {
    switch (typeIcon) {
      case 1: return 'Pill';
      case 2: return 'Syrup';
      case 3: return 'Injection';
      case 4: return 'Liquid';
      default: return 'Medicine';
    }
  }

  String _get3DAssetPath(int typeIcon) {
    switch (typeIcon) {
      case 1: return 'assets/icons/medicine/3d/tablet.png'; // Pill
      case 2: return 'assets/icons/medicine/3d/liquid.png'; // Syrup
      case 3: return 'assets/icons/medicine/3d/injection.png'; // Injection
      case 4: return 'assets/icons/medicine/3d/drop.png'; // Drops/Liquid
      default: return 'assets/icons/medicine/3d/tablet.png';
    }
  }
}

