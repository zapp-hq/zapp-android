import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'action_selection_screen.dart';
import 'zapp_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> _linkedDevices = [];
  List<Map<String, dynamic>> _incomingZapps = [];
  bool _isOverlayEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLinkedDevices();
    _loadIncomingZapps();
    _loadOverlayState();

    // Initialize overlay manager
    ZappOverlayManager.initialize(context);
  }

  /// Load linked devices from SharedPreferences
  Future<void> _loadLinkedDevices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceList = prefs.getStringList('linked_devices') ?? [];

      setState(() {
        _linkedDevices = deviceList.map((deviceData) {
          final parts = deviceData.split('|');
          return {
            'name': parts[0],
            'publicKey': parts.length > 1 ? parts[1] : '',
            'fingerprint': parts.length > 2 ? parts[2] : '',
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading linked devices: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Load incoming zapps (placeholder for real-time messaging)
  Future<void> _loadIncomingZapps() async {
    try {
      // **PLACEHOLDER:** In production, this would connect to a real-time messaging system
      // to receive incoming zapps from other linked devices

      // Simulate some incoming zapps for demo purposes
      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _incomingZapps = [
          {
            'id': '1',
            'from': 'John iPhone',
            'content': 'Check out this article about Flutter development',
            'action': 'bookmark',
            'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
            'isRead': false,
          },
          {
            'id': '2',
            'from': 'Work Laptop',
            'content': 'Meeting notes from today standup',
            'action': 'notion',
            'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
            'isRead': true,
          },
        ];
      });
    } catch (e) {
      print('Error loading incoming zapps: $e');
    }
  }

  /// Load overlay state from SharedPreferences
  Future<void> _loadOverlayState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isOverlayEnabled = prefs.getBool('overlay_enabled') ?? false;
      });

      // If overlay was enabled, restore it
      if (_isOverlayEnabled) {
        ZappOverlayManager.showOverlay();
      }
    } catch (e) {
      print('Error loading overlay state: $e');
    }
  }

  /// Save overlay state to SharedPreferences
  Future<void> _saveOverlayState(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('overlay_enabled', enabled);
    } catch (e) {
      print('Error saving overlay state: $e');
    }
  }

  /// Remove a linked device
  Future<void> _removeDevice(int index) async {
    final device = _linkedDevices[index];

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device'),
        content: Text('Are you sure you want to remove "${device['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _linkedDevices.removeAt(index);
      });

      // Save updated list to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final deviceList = _linkedDevices.map((device) {
        return '${device['name']}|${device['publicKey']}|${device['fingerprint']}';
      }).toList();
      await prefs.setStringList('linked_devices', deviceList);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed device "${device['name']}"'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Toggle overlay visibility
  Future<void> _toggleOverlay(bool enabled) async {
    if (enabled) {
      // Check and request permission first
      bool hasPermission = await ZappOverlayManager.hasOverlayPermission();
      if (!hasPermission) {
        hasPermission = await ZappOverlayManager.requestOverlayPermission();
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Overlay permission is required for the Zapp button',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      final success = await ZappOverlayManager.showOverlay();
      if (success) {
        setState(() {
          _isOverlayEnabled = true;
        });
        await _saveOverlayState(true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Zapp overlay enabled! Tap the floating button from any app.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      final success = await ZappOverlayManager.hideOverlay();
      if (success) {
        setState(() {
          _isOverlayEnabled = false;
        });
        await _saveOverlayState(false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Zapp overlay disabled'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      }
    }
  }

  /// Handle incoming zapp tap
  void _handleIncomingZappTap(Map<String, dynamic> zapp) {
    // Mark as read
    setState(() {
      zapp['isRead'] = true;
    });

    // Show zapp details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Zapp from ${zapp['from']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Content:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(zapp['content']),
            const SizedBox(height: 12),
            Text(
              'Action: ${zapp['action']}',
              style: TextStyle(color: Colors.blue),
            ),
            const SizedBox(height: 4),
            Text(
              'Received: ${_formatTime(zapp['timestamp'])}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Execute the zapp action
              print(
                'Executing zapp action: ${zapp['action']} with content: ${zapp['content']}',
              );
            },
            child: const Text('Execute'),
          ),
        ],
      ),
    );
  }

  /// Format timestamp for display
  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Build linked devices section
  Widget _buildLinkedDevicesSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.devices, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Linked Devices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_linkedDevices.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No devices linked yet. Use "Link New Device" to get started.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _linkedDevices.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final device = _linkedDevices[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.smartphone, color: Colors.white),
                    ),
                    title: Text(device['name']!),
                    subtitle: Text(
                      'Fingerprint: ${device['fingerprint']?.substring(0, 16) ?? 'Unknown'}...',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeDevice(index),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Build incoming zapps section
  Widget _buildIncomingZappsSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inbox, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Incoming Zapps',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_incomingZapps.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.all_inbox, color: Colors.grey),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No incoming zapps. Share content from your other devices!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _incomingZapps.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final zapp = _incomingZapps[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: zapp['isRead']
                          ? Colors.grey
                          : Colors.orange,
                      child: Icon(
                        Icons.flash_on,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      zapp['content'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: zapp['isRead']
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'From ${zapp['from']} • ${_formatTime(zapp['timestamp'])}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Chip(
                      label: Text(
                        zapp['action'],
                        style: const TextStyle(fontSize: 10),
                      ),
                      backgroundColor: Colors.blue[100],
                    ),
                    onTap: () => _handleIncomingZappTap(zapp),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.flash_on, color: Colors.yellow),
            SizedBox(width: 8),
            Text('Zapp Devices'),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadLinkedDevices();
              _loadIncomingZapps();
            },
            tooltip: 'Refresh',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildLinkedDevicesSection(),
              const SizedBox(height: 8),

              // Zapp Overlay Toggle Section
              ZappOverlayDemo(),

              const SizedBox(height: 8),
              _buildIncomingZappsSection(),
              const SizedBox(height: 16),

              // Quick Test Button for Action Selection Screen
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ActionSelectionScreen(),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Test Action Selection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    ZappOverlayManager.dispose();
    super.dispose();
  }
}
