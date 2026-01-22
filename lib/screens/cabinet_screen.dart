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
      backgroundColor: Colors.transparent, // Handled by MainScreen
      appBar: AppBar(
        title: const Text('Medicine Cabinet', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
            onPressed: () => _navigateToAddMedicine(context),
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 16),
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

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), // Bottom padding for nav bar
            itemCount: medicines.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final medicine = medicines[index];
              return _buildMedicineCard(context, medicine, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildMedicineCard(BuildContext context, Medicine medicine, bool isDark) {
    final color = Color(medicine.color);
    // Determine stock status - Placeholder logic until stock field is real
    // final isLowStock = medicine.currentStock <= medicine.lowStockThreshold; 
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _navigateToAddMedicine(context, medicine: medicine),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Hero(
                  tag: 'cabinet_icon_${medicine.id}',
                  child: Image.asset(
                    medicine.iconAssetPath,
                    width: 48,
                    height: 48,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              medicine.dosage,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Edit Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
              ],
            ),
          ),
        ),
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
