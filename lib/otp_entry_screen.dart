import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OTPEntryScreen extends StatefulWidget {
  const OTPEntryScreen({super.key});

  @override
  State<OTPEntryScreen> createState() => _OTPEntryScreenState();
}

class _OTPEntryScreenState extends State<OTPEntryScreen> {
  final TextEditingController _otpController = TextEditingController();
  String _localFingerprint = '';
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadLocalFingerprint();
  }

  Future<void> _loadLocalFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _localFingerprint = prefs.getString('local_pgp_fingerprint') ?? 'Not Available';
    });
  }

  Future<void> _connectWithOTP() async {
    final otp = _otpController.text.trim();
    
    if (otp.isEmpty) {
      _showSnackBar('Please enter an OTP');
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      // PLACEHOLDER: This is where native Android code would be needed
      // to send the OTP and local public key to the infra server
      // and receive the other device's public key
      
      await _performDeviceLinking(otp);
      
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar('Device linked successfully!');
      }
    } catch (e) {
      _showSnackBar('Failed to link device: \$e');
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _performDeviceLinking(String otp) async {
    // CRUCIAL PLACEHOLDER: Native Android integration needed here
    // 
    // This method represents where you would need to implement:
    // 1. Network communication with the tiny infra server
    // 2. Send local public key and OTP to server
    // 3. Receive remote device's public key from server
    // 4. Verify the linking process
    // 
    // The native Android code would handle:
    // - HTTP/HTTPS requests to the server
    // - JSON parsing of responses
    // - Error handling for network issues
    // - Timeout management
    // 
    // Example server communication flow:
    // POST /link-device
    // Body: {
    //   "otp": "123456",
    //   "publicKey": "-----BEGIN PGP PUBLIC KEY BLOCK-----...",
    //   "deviceName": "My Android Device"
    // }
    // 
    // Response: {
    //   "success": true,
    //   "remotePublicKey": "-----BEGIN PGP PUBLIC KEY BLOCK-----...",
    //   "remoteDeviceName": "Other Device",
    //   "remoteFingerprint": "ABCD1234..."
    // }

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    
    // For demonstration, we'll add a mock linked device
    final prefs = await SharedPreferences.getInstance();
    final deviceList = prefs.getStringList('linked_devices') ?? [];
    
    // Mock remote device data (in real implementation, this comes from server)
    final mockRemoteDevice = 'Remote Device|MOCK_REMOTE_PUBLIC_KEY|REMOTE_FINGERPRINT_\$otp';
    deviceList.add(mockRemoteDevice);
    
    await prefs.setStringList('linked_devices', deviceList);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Device'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Icon(
              Icons.link,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Enter OTP to Link Device',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Enter the 6-digit OTP generated on the other device to establish a secure connection.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // OTP Input Field
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'OTP Code',
                hintText: '123456',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.security),
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Connect Button
            ElevatedButton(
              onPressed: _isConnecting ? null : _connectWithOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isConnecting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Connecting...'),
                      ],
                    )
                  : const Text(
                      'Connect Device',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 32),

            // Local Device Information
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Your Device Fingerprint',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        _localFingerprint,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Share this fingerprint with the other device for verification (optional).',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Native Integration Note
            Card(
              color: Colors.orange[50],
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(height: 8),
                    Text(
                      'NATIVE ANDROID INTEGRATION REQUIRED',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This screen requires native Android code to:\\n'
                      '• Send OTP and public key to server\\n'
                      '• Receive remote device public key\\n'
                      '• Handle network communication\\n'
                      '• Manage secure key exchange',
                      style: TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
