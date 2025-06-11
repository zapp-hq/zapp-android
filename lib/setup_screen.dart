import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'otp_entry_screen.dart';
import 'crypto_utils.dart';
import 'storage_service.dart';

/// Setup screen shown on first launch for device linking and key generation
/// Handles PGP key generation and initial device configuration
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _isGeneratingKeys = false;
  String _statusMessage = 'Welcome to Zapp!';
  String? _deviceFingerprint;

  @override
  void initState() {
    super.initState();
    _checkExistingKeys();
  }

  /// Check if keys already exist on app startup
  Future<void> _checkExistingKeys() async {
    try {
      final keyPair = await StorageService.loadKeyPair();
      if (keyPair != null) {
        setState(() {
          _deviceFingerprint = keyPair['fingerprint'] as String;
          _statusMessage =
              'Device keys found. Ready to link with other devices.';
        });
      } else {
        setState(() {
          _statusMessage =
              'No device keys found. Generate keys to get started.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking existing keys: \$e';
      });
    }
  }

  /// Generate RSA key pair in background and save securely
  /// This happens automatically on first launch or can be triggered manually
  Future<void> _generateAndSaveKeyPair() async {
    setState(() {
      _isGeneratingKeys = true;
      _statusMessage = 'Generating RSA key pair... This may take a moment.';
    });

    try {
      // Generate 2048-bit RSA key pair for good security/performance balance
      if (kDebugMode) {
        print('Starting RSA key generation...');
      }
      final keyPair = CryptoUtils.generateKeyPair(bitLength: 2048);

      if (kDebugMode) {
        print('Key generation completed, saving to storage...');
      }

      // Save the key pair securely
      final saved = await StorageService.saveKeyPair(
          keyPair.publicKey, keyPair.privateKey);

      if (saved) {
        // Generate and display fingerprint
        final fingerprint = CryptoUtils.generateFingerprint(keyPair.publicKey);

        setState(() {
          _deviceFingerprint = fingerprint;
          _statusMessage = 'Keys generated successfully!';
          _isGeneratingKeys = false;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Device keys generated with fingerprint: \$fingerprint'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Failed to save generated keys');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error generating keys: \$e';
        _isGeneratingKeys = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Key generation failed: \$e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Navigate to OTP entry screen for device linking
  void _navigateToOTPEntry() {
    if (_deviceFingerprint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please generate device keys first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OTPEntryScreen(),
      ),
    );
  }

  /// Navigate to main app screen
  void _navigateToMainApp() {
    if (_deviceFingerprint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please generate device keys first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Zapp!'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.flash_on,
                    size: 64,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to Zapp!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Secure cross-device communication with end-to-end encryption',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.blue.shade600,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Status Message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isGeneratingKeys
                    ? Colors.orange.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isGeneratingKeys
                      ? Colors.orange.shade200
                      : Colors.green.shade200,
                ),
              ),
              child: Row(
                children: [
                  _isGeneratingKeys
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _deviceFingerprint != null
                              ? Icons.check_circle
                              : Icons.info,
                          color: _deviceFingerprint != null
                              ? Colors.green
                              : Colors.blue,
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _isGeneratingKeys
                            ? Colors.orange.shade800
                            : Colors.green.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Device Fingerprint Display
            if (_deviceFingerprint != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fingerprint, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Device Fingerprint',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SelectableText(
                        _deviceFingerprint!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Key Generation Button
            if (_deviceFingerprint == null) ...[
              ElevatedButton.icon(
                onPressed: _isGeneratingKeys ? null : _generateAndSaveKeyPair,
                icon: _isGeneratingKeys
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.vpn_key),
                label: Text(_isGeneratingKeys
                    ? 'Generating Keys...'
                    : 'Generate Device Keys'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            if (_deviceFingerprint != null) ...[
              ElevatedButton.icon(
                onPressed: _navigateToOTPEntry,
                icon: const Icon(Icons.link),
                label: const Text('Link New Device (via OTP)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _navigateToMainApp,
                icon: const Icon(Icons.devices),
                label: const Text('My Devices'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Security Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Security Information',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Your device generates a unique RSA-2048 key pair for secure communication\\n'
                    '• Private keys are stored locally and never shared\\n'
                    '• Device fingerprints help verify authentic connections\\n'
                    '• All messages are encrypted end-to-end between devices',
                    style: TextStyle(
                      color: Colors.amber.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
