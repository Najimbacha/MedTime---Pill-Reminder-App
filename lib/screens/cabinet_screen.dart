import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/medicine_provider.dart';
import '../models/medicine.dart';
import '../widgets/empty_state_widget.dart';
import 'add_edit_medicine_screen.dart';

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
        actions: [
          GestureDetector(
            onTap: () => _navigateToAddMedicine(context),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<MedicineProvider>(
        builder: (context, provider, child) {
          final medicines = provider.medicines;
          
          if (medicines.isEmpty) {
            return Center(
              child: EmptyStateWidget(
                icon: Icons.medication_outlined,
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
    );
  }

  void _navigateToAddMedicine(BuildContext context, {Medicine? medicine}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditMedicineScreen(medicine: medicine),
      ),
    );
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
    final color = Color(medicine.color);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Medicine Icon with colored background
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                medicine.iconAssetPath,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 14),
            
            // Medicine Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    medicine.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  
                  // Info Row: Dosage + Frequency
                  Row(
                    children: [
                      // Dosage chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.white.withOpacity(0.1) 
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          medicine.dosage,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Type indicator
                      Icon(
                        _getTypeIcon(medicine.typeIcon),
                        size: 14,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getTypeName(medicine.typeIcon),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
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
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(int typeIcon) {
    switch (typeIcon) {
      case 1: return Icons.medication_rounded;
      case 2: return Icons.local_drink_rounded;
      case 3: return Icons.vaccines_rounded;
      case 4: return Icons.water_drop_rounded;
      default: return Icons.medication_rounded;
    }
  }

  String _getTypeName(int typeIcon) {
    switch (typeIcon) {
      case 1: return 'Pill';
      case 2: return 'Syrup';
      case 3: return 'Injection';
      case 4: return 'Drops';
      default: return 'Medicine';
    }
  }
}

