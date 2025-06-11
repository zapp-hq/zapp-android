import 'package:flutter/material.dart';

class ActionSelectionScreen extends StatefulWidget {
  const ActionSelectionScreen({Key? key}) : super(key: key);

  @override
  State<ActionSelectionScreen> createState() => _ActionSelectionScreenState();
}

class _ActionSelectionScreenState extends State<ActionSelectionScreen> {
  // Controller for the intent input field
  final TextEditingController _intentController = TextEditingController();
  
  // Selected content from external app (initially dummy data)
  String _selectedContent = '';
  
  // Currently selected action
  String _selectedAction = '';
  
  // List of available actions
  final List<Map<String, dynamic>> _actionButtons = [
    {'label': 'Copy to Clipboard', 'icon': Icons.copy, 'action': 'copy'},
    {'label': 'Send to Phone', 'icon': Icons.phone_android, 'action': 'send_phone'},
    {'label': 'Send to Laptop', 'icon': Icons.laptop, 'action': 'send_laptop'},
    {'label': 'Bookmark', 'icon': Icons.bookmark_add, 'action': 'bookmark'},
    {'label': 'Google Search', 'icon': Icons.search, 'action': 'google_search'},
    {'label': 'WhatsApp', 'icon': Icons.chat, 'action': 'whatsapp'},
    {'label': 'Email', 'icon': Icons.email, 'action': 'email'},
    {'label': 'Notion', 'icon': Icons.note_add, 'action': 'notion'},
    {'label': 'Google Keep', 'icon': Icons.notes, 'action': 'google_keep'},
  ];
  
  // Loading state
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedContent();
    
    // Listen for changes in the intent field to update send button state
    _intentController.addListener(_updateSendButtonState);
  }

  @override
  void dispose() {
    _intentController.dispose();
    super.dispose();
  }

  /// Load selected content from external app
  /// **CRUCIAL PLACEHOLDER:** This method demonstrates where AccessibilityService integration would occur
  Future<void> _loadSelectedContent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // **NATIVE INTEGRATION REQUIRED:**
      // This is where the actual MethodChannel call to get selected content would go.
      // The AccessibilityService running on the native Android side would capture
      // selected text from other applications and send it to Flutter through this channel.
      //
      // Example of what the actual implementation would look like:
      // const platform = MethodChannel('com.zapp.accessibility/content');
      // final String content = await platform.invokeMethod('getSelectedContent');
      //
      // **REQUIRED PERMISSIONS in AndroidManifest.xml:**
      // <uses-permission android:name="android.permission.BIND_ACCESSIBILITY_SERVICE" />
      //
      // **REQUIRED SERVICE DECLARATION in AndroidManifest.xml:**
      // <service
      //     android:name=".AccessibilityContentService"
      //     android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
      //     <intent-filter>
      //         <action android:name="android.accessibilityservice.AccessibilityService" />
      //     </intent-filter>
      //     <meta-data android:name="android.accessibilityservice"
      //                android:resource="@xml/accessibility_service_config" />
      // </service>

      // For now, using dummy data to demonstrate the UI flow
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
      
      setState(() {
        _selectedContent = 'Dummy selected text from external app. This could be a URL, paragraph, or any text content that the user has selected in another application.';
      });
    } catch (e) {
      setState(() {
        _selectedContent = 'Error loading selected content: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Update the state of the send button based on content and action selection
  void _updateSendButtonState() {
    setState(() {
      // Send button is enabled when we have selected content AND (an action is selected OR intent is entered)
    });
  }

  /// Check if send button should be enabled
  bool get _isSendEnabled {
    return _selectedContent.isNotEmpty && 
           (_selectedAction.isNotEmpty || _intentController.text.trim().isNotEmpty);
  }

  /// Handle action button selection
  void _selectAction(String action, String label) {
    setState(() {
      _selectedAction = action;
    });
    
    // Auto-fill intent field based on selected action for better UX
    switch (action) {
      case 'copy':
        _intentController.text = 'Copy this content to clipboard';
        break;
      case 'google_search':
        _intentController.text = 'Search this content on Google';
        break;
      case 'bookmark':
        _intentController.text = 'Save as bookmark for later reference';
        break;
      case 'whatsapp':
        _intentController.text = 'Share via WhatsApp';
        break;
      case 'email':
        _intentController.text = 'Send via email';
        break;
      default:
        _intentController.text = 'Process with $label';
    }
  }

  /// Handle send button press
  Future<void> _handleSend() async {
    if (!_isSendEnabled) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // **CRUCIAL PLACEHOLDER:** This is where cross-device communication would occur
      // The actual implementation would:
      // 1. Encrypt the content and intent using PGP keys from linked devices
      // 2. Send the encrypted payload to the target device via the infrastructure server
      // 3. Handle delivery confirmation and error states
      
      print('=== ZAPP ACTION EXECUTION ===');
      print('Selected Content: $_selectedContent');
      print('User Intent: ${_intentController.text}');
      print('Chosen Action: $_selectedAction');
      print('Timestamp: ${DateTime.now().toIso8601String()}');
      print('=============================');

      // Simulate processing time
      await Future.delayed(const Duration(seconds: 1));

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action "$_selectedAction" executed successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Close the action selection screen after successful execution
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pop();
      }

    } catch (e) {
      print('Error executing action: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to execute action: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Build the selected content section
  Widget _buildSelectedContentSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.content_copy, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Selected Content',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _selectedContent.isEmpty ? 'Loading selected content...' : _selectedContent,
                style: TextStyle(
                  fontSize: 14,
                  color: _selectedContent.isEmpty ? Colors.grey[600] : Colors.black87,
                  fontStyle: _selectedContent.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            if (_selectedContent.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_selectedContent.length} characters',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build the intent input section
  Widget _buildIntentSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Your Intent',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _intentController,
              decoration: InputDecoration(
                hintText: 'Describe what you want to do with this content...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }

  /// Build the action buttons section
  Widget _buildActionButtonsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.flash_on, color: Colors.purple),
              SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _actionButtons.length,
            itemBuilder: (context, index) {
              final action = _actionButtons[index];
              final isSelected = _selectedAction == action['action'];
              
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ActionChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        action['icon'],
                        size: 16,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        action['label'],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => _selectAction(action['action'], action['label']),
                  backgroundColor: isSelected ? Colors.blue : Colors.grey[200],
                  elevation: isSelected ? 4 : 1,
                  pressElevation: 8,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build the send button
  Widget _buildSendButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: _isSendEnabled && !_isLoading ? _handleSend : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: _isSendEnabled ? 4 : 1,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isSendEnabled ? 'Send Zapp' : 'Select Action & Content',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
            Text('Zapp Action'),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildSelectedContentSection(),
                  const SizedBox(height: 8),
                  _buildIntentSection(),
                  const SizedBox(height: 16),
                  _buildActionButtonsSection(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _buildSendButton(),
        ],
      ),
    );
  }
}
