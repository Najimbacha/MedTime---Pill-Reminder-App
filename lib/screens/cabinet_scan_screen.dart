import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../utils/haptic_helper.dart';
import '../utils/sound_helper.dart';
import 'add_edit_medicine_screen.dart';

/// Screen for scanning medicine bottles using AI
class CabinetScanScreen extends StatefulWidget {
  const CabinetScanScreen({super.key});

  @override
  State<CabinetScanScreen> createState() => _CabinetScanScreenState();
}

class _CabinetScanScreenState extends State<CabinetScanScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isPermissionGranted = false;
  bool _isScanning = false;
  String _lastRecognizedText = "";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final firstCamera = cameras.first;
    _cameraController = CameraController(
      firstCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isPermissionGranted = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _scanText() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isScanning) {
      return;
    }

    setState(() => _isScanning = true);
    await HapticHelper.selection();

    try {
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      setState(() {
        _lastRecognizedText = recognizedText.text;
        _isScanning = false;
      });

      if (_lastRecognizedText.isNotEmpty) {
        await SoundHelper.playClick();
        _showResultsDialog(_lastRecognizedText);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text recognized. Try again.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error scanning text: $e');
      setState(() => _isScanning = false);
    }
  }

  void _showResultsDialog(String text) {
    // Basic extraction logic: find potential names (first few capital words)
    // In a real app, this would be more sophisticated
    final lines = text.split('\n');
    final maybeName = lines.isNotEmpty ? lines[0] : "";
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recognized Text:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(text),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Identified Medicine:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(maybeName, style: const TextStyle(fontSize: 18, color: Colors.blue)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditMedicineScreen(
                    // We can't pass all data yet, but we can pre-fill the name
                    // In a production app, we'd pass a partial Medicine object
                  ),
                ),
              );
            },
            child: const Text('Use This Name'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AlertDialog(
                  title: Text('How to scan'),
                  content: Text('Hold the medicine bottle steady in front of the camera and tap the "Scan" button. The AI will try to extract the medicine name and dosage.'),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            ),
          
          // Overlay UI
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withAlpha(128),
                        width: 2,
                      ),
                    ),
                    margin: const EdgeInsets.all(40),
                    child: Center(
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(179),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Align medicine bottle label within the frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: _isScanning ? null : _scanText,
                          icon: _isScanning 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.document_scanner),
                          label: Text(
                            _isScanning ? 'Scanning...' : 'Scan Bottle',
                            style: const TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
