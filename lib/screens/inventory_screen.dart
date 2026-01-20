import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/medicine_provider.dart';
import '../models/medicine.dart';
import 'add_medicine_screen.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Cabinet',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: Consumer<MedicineProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.medicines.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.medicines.length,
            itemBuilder: (context, index) {
              final medicine = provider.medicines[index];
              return _buildMedicineCard(context, medicine);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMedicineScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 100,
            color: Theme.of(context).colorScheme.primary.withAlpha(51),
          ),
          const SizedBox(height: 24),
          Text(
            'Your storage is empty',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add medicines to track your stock',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(153),
                ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddMedicineScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Medicine'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(BuildContext context, Medicine medicine) {
    final isLowStock = medicine.currentStock <= (medicine.lowStockThreshold ?? 5);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        key: PageStorageKey(medicine.id),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Color(int.parse(medicine.color.replaceFirst('#', '0xFF'))).withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getCategoryIcon(medicine.category),
            color: Color(int.parse(medicine.color.replaceFirst('#', '0xFF'))),
          ),
        ),
        title: Text(
          medicine.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isLowStock ? Colors.red.withAlpha(26) : Colors.green.withAlpha(26),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Stock: ${medicine.currentStock}',
                style: TextStyle(
                  color: isLowStock ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Dosage', style: TextStyle(color: Colors.grey)),
                        Text(medicine.dosage, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Stock', style: TextStyle(color: Colors.grey)),
                        Text('${medicine.totalStock}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Refill Information', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.local_pharmacy_outlined, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(medicine.pharmacyName ?? 'N/A'),
                    const Spacer(),
                    if (medicine.pharmacyPhone != null)
                      IconButton(
                        icon: const Icon(Icons.phone, color: Colors.green),
                        onPressed: () => _launchCaller(medicine.pharmacyPhone!),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showRefillDialog(context, medicine),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Record Refill'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddMedicineScreen(medicine: medicine),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'tablet':
        return Icons.medication_rounded;
      case 'capsule':
        return Icons.medication_liquid_rounded;
      case 'syrup':
        return Icons.liquor_rounded;
      case 'injection':
        return Icons.vaccines_rounded;
      default:
        return Icons.medication_rounded;
    }
  }

  Future<void> _launchCaller(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  void _showRefillDialog(BuildContext context, Medicine medicine) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Refill ${medicine.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantity Added',
            suffixText: 'doses',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(controller.text);
              if (quantity != null) {
                context.read<MedicineProvider>().refillMedicine(medicine.id!, quantity);
                Navigator.pop(context);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
