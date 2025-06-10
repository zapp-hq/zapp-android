import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'otp_entry_screen.dart';
import 'zapp_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> linkedDevices = [];
  List<Map<String, String>> incomingZapps = [];
  bool isOverlayEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadLinkedDevices();
    _loadOverlaySettings();
    _loadIncomingZapps();
  }

  Future<void> _loadLinkedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceList = prefs.getStringList('linked_devices') ?? [];
    
    setState(() {
      linkedDevices = deviceList.map((deviceJson) {
        // In a real implementation, you'd properly parse JSON
        // For now, we'll use a simple format: "deviceName|publicKey|fingerprint"
        final parts = deviceJson.split('|');
        return {
          'name': parts.isNotEmpty ? parts[0] : 'Unknown Device',
          'publicKey': parts.length > 1 ? parts[1] : '',
          'fingerprint': parts.length > 2 ? parts[2] : '',
        };
      }).toList();
    });
  }

  Future<void> _loadOverlaySettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isOverlayEnabled = prefs.getBool('overlay_enabled') ?? false;
    });
  }

  Future<void> _loadIncomingZapps() async {
    final prefs = await SharedPreferences.getInstance();
    final zappList = prefs.getStringList('incoming_zapps') ?? [];
    
    setState(() {
      incomingZapps = zappList.map((zappJson) {
        // Simple format: "fromDevice|content|timestamp"
        final parts = zappJson.split('|');
        return {
          'fromDevice': parts.isNotEmpty ? parts[0] : 'Unknown',
          'content': parts.length > 1 ? parts[1] : '',
          'timestamp': parts.length > 2 ? parts[2] : '',
        };
      }).toList();
    });
  }

  Future<void> _toggleOverlay() async {
    final prefs = await SharedPreferences.getInstance();
    final newState = !isOverlayEnabled;
    
    if (newState) {
      // Request overlay permission and show overlay
      final success = await ZappOverlay.requestPermissionAndShow();
      if (success) {
        await prefs.setBool('overlay_enabled', true);
        setState(() {
          isOverlayEnabled = true;
        });
        _showSnackBar('Zapp overlay enabled');
      } else {
        _showSnackBar('Overlay permission required');
      }
    } else {
      // Hide overlay
      await ZappOverlay.hide();
      await prefs.setBool('overlay_enabled', false);
      setState(() {
        isOverlayEnabled = false;
      });
      _showSnackBar('Zapp overlay disabled');
    }
  }

  Future<void> _removeDevice(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceList = prefs.getStringList('linked_devices') ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device'),
        content: Text('Are you sure you want to remove "${linkedDevices[index]['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              deviceList.removeAt(index);
              await prefs.setStringList('linked_devices', deviceList);
              Navigator.of(context).pop();
              _loadLinkedDevices();
              _showSnackBar('Device removed');
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
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
        title: const Text('Zapp Devices'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const OTPEntryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadLinkedDevices();
          await _loadIncomingZapps();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linked Devices Section
              _buildSectionHeader('Linked Devices', Icons.devices),
              const SizedBox(height: 8),
              linkedDevices.isEmpty
                  ? _buildEmptyState('No devices linked yet', Icons.devices_other)
                  : _buildDeviceList(),
              const SizedBox(height: 24),

              // Zapp Overlay Toggle Section
              _buildSectionHeader('Zapp Overlay', Icons.picture_in_picture),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app, color: Colors.blue),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Always-On Zapp Button',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Show floating button for quick access',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isOverlayEnabled,
                        onChanged: (value) => _toggleOverlay(),
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Incoming Zapps Section
              _buildSectionHeader('Incoming Zapps', Icons.inbox),
              const SizedBox(height: 8),
              incomingZapps.isEmpty
                  ? _buildEmptyState('No incoming zapps', Icons.inbox_outlined)
                  : _buildIncomingZappsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: linkedDevices.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final device = linkedDevices[index];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.smartphone, color: Colors.white),
            ),
            title: Text(device['name'] ?? 'Unknown Device'),
            subtitle: Text(
              'Fingerprint: ${device['fingerprint']}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeDevice(index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIncomingZappsList() {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: incomingZapps.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final zapp = incomingZapps[index];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.message, color: Colors.white),
            ),
            title: Text('From: ${zapp['fromDevice']}'),
            subtitle: Text(zapp['content'] ?? 'No content'),
            trailing: Text(
              zapp['timestamp'] ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}