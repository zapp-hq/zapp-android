import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'otp_entry_screen.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App Logo/Header
              const Icon(
                Icons.flash_on,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              
              // Welcome Text
              const Text(
                'Welcome to Zapp!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              const Text(
                'Securely connect your devices and share information instantly.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Link New Device Button
              ElevatedButton.icon(
                onPressed: () => _navigateToOTPEntry(),
                icon: const Icon(Icons.link),
                label: const Text('Link New Device (via OTP)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              
              // My Devices Button
              OutlinedButton.icon(
                onPressed: () => _navigateToMainApp(),
                icon: const Icon(Icons.devices),
                label: const Text('My Devices'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 32),
              
              // Info Text
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(height: 8),
                      Text(
                        'Your device is automatically secured with PGP encryption. '
                        'Keys are generated and stored locally on first launch.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToOTPEntry() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const OTPEntryScreen(),
      ),
    );
  }

  void _navigateToMainApp() async {
    // Ensure PGP keys are generated before navigating to main app
    final prefs = await SharedPreferences.getInstance();
    final pgpKeyExists = prefs.getString('local_pgp_private_key') != null;
    
    if (!pgpKeyExists) {
      // Generate PGP keys if they don't exist
      await _ensurePGPKeysGenerated();
    }
    
    // Navigate to main app screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    }
  }

  Future<void> _ensurePGPKeysGenerated() async {
    // Show loading dialog while generating keys
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating secure keys...'),
            ],
          ),
        ),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    
    // PLACEHOLDER: PGP Key Generation
    // This is where you would implement actual PGP key generation
    // using the openpgp package. For now, we'll use placeholder values.
    await Future.delayed(const Duration(seconds: 2)); // Simulate key generation time
    
    await prefs.setString('local_pgp_private_key', 'PLACEHOLDER_PRIVATE_KEY');
    await prefs.setString('local_pgp_public_key', 'PLACEHOLDER_PUBLIC_KEY');
    await prefs.setString('local_pgp_fingerprint', 'ABCD1234EFGH5678');
    
    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog
    }
  }
}
