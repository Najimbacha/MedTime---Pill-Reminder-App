import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/medicine.dart';
import '../models/schedule.dart';
import '../providers/medicine_provider.dart';
import '../providers/schedule_provider.dart';
import 'add_edit_medicine_screen.dart';
import 'cabinet_scan_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';
import '../utils/caregiver_helper.dart';
import '../utils/haptic_helper.dart';
import '../utils/sound_helper.dart';

/// Screen showing all medicines in inventory
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Medicine Inventory',
          style: TextStyle(fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner, size: 28),
            tooltip: 'Scan Medicine Bottle',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CabinetScanScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<MedicineProvider>(
        builder: (context, medicineProvider, child) {
          final medicines = medicineProvider.medicines;

          if (medicines.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: medicines.length,
            itemBuilder: (context, index) {
              final medicine = medicines[index];
              return _buildMedicineCard(context, medicine);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditMedicineScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add, size: 28),
        label: const Text(
          'Add Medicine',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 120,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'No Medicines in Inventory',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add medicines to track your inventory',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineCard(BuildContext context, Medicine medicine) {
    final isLowStock = medicine.isLowStock;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'med-icon-${medicine.id}',
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: medicine.colorValue.withAlpha(38),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: medicine.imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(medicine.imagePath!),
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            medicine.icon,
                            color: medicine.colorValue,
                            size: 32,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                          Text(
                            medicine.dosage,
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    ),
                      _buildMedicinePopup(context, medicine),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Stock Status
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLowStock ? Theme.of(context).colorScheme.error.withAlpha(128) : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isLowStock ? Icons.warning_rounded : Icons.inventory_2_outlined,
                          size: 20,
                          color: isLowStock ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Stock: ${medicine.currentStock} remaining',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isLowStock ? Theme.of(context).colorScheme.error : null,
                              fontWeight: isLowStock ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                        if (isLowStock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'LOW STOCK',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                  ),
                  
                  if (isLowStock)
                    Consumer<SettingsService>(
                      builder: (context, settings, _) {
                        final caregiver = settings.caregiver;
                        if (caregiver != null && caregiver.notifyOnLowStock) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await HapticHelper.selection();
                                  await SoundHelper.playClick();
                                  CaregiverHelper.sendLowStockAlert(
                                    caregiver, 
                                    medicine.name, 
                                    medicine.currentStock
                                  );
                                },
                                icon: const Icon(Icons.sms_outlined, size: 16),
                                label: Text('Ask ${caregiver.name} for Refill'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                  side: BorderSide(
                                    color: Colors.orange.withAlpha(128),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                  if (medicine.pharmacyName != null || medicine.pharmacyPhone != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_pharmacy_outlined, 
                            size: 20, 
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              medicine.pharmacyName ?? 'Pharmacy',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (medicine.pharmacyPhone != null)
                            Material(
                              color: Colors.transparent,
                              child: IconButton(
                                icon: Icon(
                                  Icons.phone_in_talk_rounded, 
                                  size: 20,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                                onPressed: () => launchUrl(Uri.parse('tel:${medicine.pharmacyPhone}')),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Call Pharmacy',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildRefillPrediction(context, medicine),
                ],
              ),
            ),
    );
  }

  Widget _buildMedicinePopup(BuildContext context, Medicine medicine) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        if (value == 'edit') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditMedicineScreen(medicine: medicine),
            ),
          );
        } else if (value == 'delete') {
          _showDeleteDialog(context, medicine);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 20),
              SizedBox(width: 12),
              Text('Edit', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: Colors.red, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRefillPrediction(BuildContext context, Medicine medicine) {
    if (medicine.currentStock <= 0) return const SizedBox.shrink();

    final scheduleProvider = context.read<ScheduleProvider>();
    final schedules = scheduleProvider.getSchedulesForMedicine(medicine.id!);
    
    // Calculate daily doses
    int dailyDoses = 0;
    for (var schedule in schedules) {
      if (schedule.frequencyType == FrequencyType.daily) {
        dailyDoses += 1;
      } else if (schedule.frequencyType == FrequencyType.specificDays) {
        // Simplified for specificDays: average doses per day
        final daysPerWeek = schedule.daysList.length;
        if (daysPerWeek > 0) {
          // Note: This logic is simplified for prediction
        }
      }
    }

    if (dailyDoses == 0) return const SizedBox.shrink();

    final refillDate = medicine.getEstimatedRefillDate(dailyDoses);
    final daysRemaining = medicine.getDaysRemaining(dailyDoses);
    final dateFormat = DateFormat('MMM d, yyyy');
    
    Color textColor = Colors.grey[600]!;
    if (daysRemaining <= 3) textColor = Colors.orange[800]!;
    if (daysRemaining <= 1) textColor = Colors.red[800]!;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.event_repeat, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            'Refill by: ${dateFormat.format(refillDate)} (${daysRemaining}d left)',
            style: TextStyle(
              fontSize: 14,
              color: textColor,
              fontWeight: daysRemaining <= 3 ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Medicine medicine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medicine', style: TextStyle(fontSize: 22)),
        content: Text(
          'Are you sure you want to delete ${medicine.name}? This will also delete all schedules and logs.',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () async {
              final medicineProvider = context.read<MedicineProvider>();
              final scheduleProvider = context.read<ScheduleProvider>();

              // Delete schedules first
              await scheduleProvider.deleteSchedule(medicine.id!);

              // Delete medicine
              await medicineProvider.deleteMedicine(medicine.id!);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '✓ Medicine deleted',
                      style: TextStyle(fontSize: 18),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
