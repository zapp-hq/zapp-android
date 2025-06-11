import 'dart:convert';

import 'package:flutter/material.dart';
import 'action_selection_screen.dart';
import 'otp_entry_screen.dart';
import 'crypto_utils.dart';
import 'storage_service.dart';

/// Main app screen showing linked devices and overlay controls
/// Displays device management with cryptographic fingerprints
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _linkedDevices = [];
  bool _overlayEnabled = false;
  bool _isLoading = true;
  String? _localFingerprint;
  List<Map<String, dynamic>> _incomingZapps = [];

  @override
  void initState() {
    super.initState();
    _loadDeviceData();
    _loadIncomingZapps();
  }

  /// Load local device fingerprint and linked devices
  Future<void> _loadDeviceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load local key pair and fingerprint
      final keyPair = await StorageService.loadKeyPair();
      if (keyPair != null) {
        _localFingerprint = keyPair['fingerprint'] as String;
      }

      // Load linked devices
      final devices = await StorageService.loadLinkedDevices();
      
      setState(() {
        _linkedDevices = devices;
        _isLoading = false;
      });

      print('Loaded \${devices.length} linked devices');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error loading device data: \$e');
    }
  }

  /// Load mock incoming Zapps for demonstration
  Future<void> _loadIncomingZapps() async {
    // Mock incoming messages that would be received from other devices
    _incomingZapps = [
      {
        'sender': 'iPhone 14',
        'content': 'Check out this article: https://example.com/article',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
        'type': 'text',
        'encrypted': true,
      },
      {
        'sender': 'MacBook Pro',
        'content': 'Selected text from research document...',
        'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        'type': 'selection',
        'encrypted': true,
      },
    ];
  }

  /// Remove a linked device with confirmation
  Future<void> _removeDevice(String deviceFingerprint, String deviceName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device'),
        content: Text('Are you sure you want to remove "\$deviceName"?\\n\\n'
                     'This will permanently delete the device link and you will need to re-pair to restore communication.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await StorageService.deleteLinkedDevice(deviceFingerprint);
        if (success) {
          await _loadDeviceData(); // Refresh the list
          _showSuccess('Device "\$deviceName" removed successfully');
        } else {
          _showError('Failed to remove device');
        }
      } catch (e) {
        _showError('Error removing device: \$e');
      }
    }
  }

  /// Test encryption/decryption with a linked device
  Future<void> _testEncryption(String deviceFingerprint) async {
    try {
      // Get the device's public key
      final devicePublicKey = await StorageService.getDevicePublicKey(deviceFingerprint);
      if (devicePublicKey == null) {
        _showError('Device public key not found');
        return;
      }

      // Get local private key
      final keyPair = await StorageService.loadKeyPair();
      if (keyPair == null) {
        _showError('Local keys not found');
        return;
      }

      final localPrivateKey = keyPair['privateKey'];
      
      // Test message
      const testMessage = 'Hello from Zapp! This is a test encrypted message.';
      
      // Encrypt message with device's public key
      final encryptedBytes = CryptoUtils.encryptMessage(testMessage, devicePublicKey);
      base64.encode(encryptedBytes);
      
      // Decrypt message with local private key (simulating the other device)
      final decryptedMessage = CryptoUtils.decryptMessage(encryptedBytes, localPrivateKey);
      
      // Show test results
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Encryption Test'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Original: \$testMessage'),
              const SizedBox(height: 8),
              Text('Encrypted: \${encryptedBase64.substring(0, 50)}...'),
              const SizedBox(height: 8),
              Text('Decrypted: \$decryptedMessage'),
              const SizedBox(height: 8),
              Text(
                testMessage == decryptedMessage ? '✅ Test Successful' : '❌ Test Failed',
                style: TextStyle(
                  color: testMessage == decryptedMessage ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Encryption test failed: \$e');
    }
  }

  /// Toggle overlay functionality
  void _toggleOverlay() {
    setState(() {
      _overlayEnabled = !_overlayEnabled;
    });

    _showSuccess(_overlayEnabled 
        ? 'Overlay enabled - Button will appear system-wide' 
        : 'Overlay disabled');

    // **NATIVE INTEGRATION REQUIRED:**
    // In production, this would call the native overlay service
    // through MethodChannel to show/hide the system overlay
  }

  /// Navigate to OTP entry for linking new device
  void _navigateToOTPEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OTPEntryScreen(),
      ),
    ).then((_) {
      // Refresh device list when returning
      _loadDeviceData();
    });
  }

  /// Test Action Selection Screen
  void _testActionSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ActionSelectionScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show success message
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zapp Devices'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeviceData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add_link),
            onPressed: _navigateToOTPEntry,
            tooltip: 'Link New Device',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDeviceData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Local Device Info
                    if (_localFingerprint != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.phone_android, color: Colors.blue.shade600),
                                const SizedBox(width: 8),
                                Text(
                                  'This Device',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Fingerprint: \$_localFingerprint',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Linked Devices Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.devices),
                                const SizedBox(width: 8),
                                Text(
                                  'Linked Devices (\${_linkedDevices.length})',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            if (_linkedDevices.isEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.devices_other,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No devices linked yet',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap the + button to link your first device',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _linkedDevices.length,
                                separatorBuilder: (context, index) => const Divider(),
                                itemBuilder: (context, index) {
                                  final device = _linkedDevices[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.shade100,
                                      child: Icon(
                                        Icons.devices,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                    title: Text(
                                      device['deviceName'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Fingerprint: ${device['deviceFingerprint'] as String}',
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 10,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Added: ${DateTime.parse(device['dateAdded'] as String).toLocal().toString().split('.')[0]}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'test':
                                            _testEncryption(device['deviceFingerprint'] as String);
                                            break;
                                          case 'remove':
                                            _removeDevice(
                                              device['deviceFingerprint'] as String,
                                              device['deviceName'] as String,
                                            );
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'test',
                                          child: Row(
                                            children: [
                                              Icon(Icons.security, size: 16),
                                              SizedBox(width: 8),
                                              Text('Test Encryption'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'remove',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete, size: 16, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Remove Device', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Overlay Controls Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.toggle_on),
                                const SizedBox(width: 8),
                                Text(
                                  'Zapp Overlay',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'System-wide Zapp Button',
                                        style: TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        _overlayEnabled 
                                            ? 'Tap anywhere to capture content' 
                                            : 'Enable to show floating button',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _overlayEnabled,
                                  onChanged: (_) => _toggleOverlay(),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            ElevatedButton.icon(
                              onPressed: _testActionSelection,
                              icon: const Icon(Icons.touch_app),
                              label: const Text('Test Action Selection'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Incoming Zapps Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.inbox),
                                const SizedBox(width: 8),
                                Text(
                                  'Incoming Zapps',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            if (_incomingZapps.isEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No incoming Zapps',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _incomingZapps.length,
                                separatorBuilder: (context, index) => const Divider(),
                                itemBuilder: (context, index) {
                                  final zapp = _incomingZapps[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      child: Icon(
                                        zapp['type'] == 'text' ? Icons.message : Icons.select_all,
                                        color: Colors.green.shade600,
                                        size: 16,
                                      ),
                                    ),
                                    title: Text(
                                      'From: ${zapp['sender']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          zapp['content'] as String,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.lock,
                                              size: 12,
                                              color: Colors.green.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Encrypted',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.green.shade600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${DateTime.now().difference(zapp['timestamp'] as DateTime).inMinutes}m ago',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                    onTap: () {
                                      // Handle tapping on received Zapp
                                      _showSuccess('Opened Zapp from ${zapp['sender']}');
                                    },
                                  );
                                },
                              ),
                            ],
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
}