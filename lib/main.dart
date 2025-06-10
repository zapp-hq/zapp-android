import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'setup_screen.dart';
import 'home_screen.dart';

void main() {
  runApp(const ZappApp());
}

class ZappApp extends StatelessWidget {
  const ZappApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zapp!',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AppInitializer(),
      // Define named routes for navigation
      routes: {
        '/setup': (context) => const SetupScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _hasLinkedDevices = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Check if user has already linked devices or has gone through setup
    final prefs = await SharedPreferences.getInstance();
    
    // Check if PGP key exists
    final pgpKeyExists = prefs.getString('local_pgp_private_key') != null;
    
    // Check if user has linked devices
    final linkedDevices = prefs.getStringList('linked_devices') ?? [];
    final hasLinkedDevices = linkedDevices.isNotEmpty;
    
    // TODO: Generate PGP key pair if not exists
    // This is a placeholder for PGP key generation
    if (!pgpKeyExists) {
      await _generatePGPKeyPair(prefs);
    }

    setState(() {
      _hasLinkedDevices = hasLinkedDevices;
      _isLoading = false;
    });
  }

  Future<void> _generatePGPKeyPair(SharedPreferences prefs) async {
    // PLACEHOLDER: PGP Key Generation
    // In a real implementation, you would use the openpgp package here
    // Example placeholder code structure:
    // 
    // import 'package:openpgp/openpgp.dart';
    // 
    // final keyPair = await OpenPGP.generate(options: KeyOptions()
    //   ..rsaBits = 2048
    //   ..userIDs = ['Zapp User <user@zapp.com>']
    //   ..passphrase = 'secure_passphrase');
    // 
    // await prefs.setString('local_pgp_private_key', keyPair.privateKey);
    // await prefs.setString('local_pgp_public_key', keyPair.publicKey);
    // await prefs.setString('local_pgp_fingerprint', keyPair.fingerprint);
    
    // For now, store placeholder values
    await prefs.setString('local_pgp_private_key', 'PLACEHOLDER_PRIVATE_KEY');
    await prefs.setString('local_pgp_public_key', 'PLACEHOLDER_PUBLIC_KEY');
    await prefs.setString('local_pgp_fingerprint', 'ABCD1234EFGH5678');
    
    print('PGP key pair generated and stored locally');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.blue[50],
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Initializing Zapp...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Navigate to appropriate screen based on setup status
    return _hasLinkedDevices ? const HomeScreen() : const SetupScreen();
  }
}
