import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/caregiver_invite.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../utils/haptic_helper.dart';

/// Screen for patients to invite caregivers via invite code
class InviteCaregiverScreen extends StatefulWidget {
  const InviteCaregiverScreen({super.key});

  @override
  State<InviteCaregiverScreen> createState() => _InviteCaregiverScreenState();
}

class _InviteCaregiverScreenState extends State<InviteCaregiverScreen> {
  final AuthService _authService = AuthService();
  CaregiverInvite? _invite;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateInvite();
  }

  Future<void> _generateInvite() async {
    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isSignedIn) {
      setState(() {
        _error = 'Please sign in to invite caregivers';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = authProvider.userProfile;
      
      // Auto-enable sharing when inviting a caregiver
      if (profile != null && !profile.shareEnabled) {
         await authProvider.setShareEnabled(true);
      }

      _invite = await _authService.generateInviteCode(
        patientName: profile?.displayName,
      );
      await HapticHelper.success();
    } catch (e) {
      _error = 'Failed to generate invite code: $e';
      await HapticHelper.error();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _copyCode() async {
    if (_invite == null) return;

    await Clipboard.setData(ClipboardData(text: _invite!.code));
    await HapticHelper.success();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite code copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareCode() async {
    if (_invite == null) return;

    await HapticHelper.selection();
    await Share.share(
      'Join me on MedTime to help track my medication!\n\n'
      'Download the MedTime app and use this invite code:\n\n'
      '${_invite!.code}\n\n'
      'This code expires in 24 hours.',
      subject: 'MedTime Caregiver Invite',
    );
  }

  String _formatTimeRemaining() {
    if (_invite == null) return '';

    final remaining = _invite!.expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    if (hours > 0) {
      return 'Expires in ${hours}h ${minutes}m';
    }
    return 'Expires in ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Invite Caregiver',
          style: theme.textTheme.headlineMedium,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildInviteView(colorScheme),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _generateInvite,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteView(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.family_restroom,
                    color: colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Share this code with your caregiver so they can monitor your medication adherence.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: 'medtime://invite/${_invite?.code ?? ''}',
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 24),

          // Invite Code
          Text(
            'Invite Code',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _copyCode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _invite?.code ?? '------',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.copy,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatTimeRemaining(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),

          // Share Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareCode,
              icon: const Icon(Icons.share),
              label: const Text('Share Invite'),
            ),
          ),
          const SizedBox(height: 16),

          // Regenerate Button
          TextButton.icon(
            onPressed: _generateInvite,
            icon: const Icon(Icons.refresh),
            label: const Text('Generate New Code'),
          ),
          const SizedBox(height: 32),

          // Instructions
          Card(
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How it works:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildStep('1', 'Share the code with your caregiver'),
                  _buildStep('2', 'They enter the code in their MedTime app'),
                  _buildStep('3', 'They can view your medication schedule'),
                  _buildStep('4', 'They receive alerts if you miss a dose'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              number,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
