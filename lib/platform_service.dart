import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class PlatformService {
  // Define the MethodChannel with a unique identifier
  static const MethodChannel _methodChannel =
      MethodChannel('com.zapp.app/platform_features');

  // Event channel for receiving selected text updates
  static const EventChannel _selectedTextChannel =
      EventChannel('com.zapp.app/selected_text');

  // Stream controller for selected text events
  static StreamController<String>? _selectedTextController;

  /// Initialize the platform service and set up event listeners
  static Future<void> initialize() async {
    _setupSelectedTextListener();
  }

  /// Check if overlay permission is granted
  static Future<bool> hasOverlayPermission() async {
    try {
      final bool result =
          await _methodChannel.invokeMethod('hasOverlayPermission');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error checking overlay permission: ${e.message}');
      }
      return false;
    }
  }

  /// Request overlay permission from user
  /// Opens Android Settings page for the user to manually grant permission
  static Future<bool> requestOverlayPermission() async {
    try {
      final bool result =
          await _methodChannel.invokeMethod('requestOverlayPermission');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error requesting overlay permission: ${e.message}');
      }
      return false;
    }
  }

  /// Check if accessibility service is enabled
  static Future<bool> hasAccessibilityPermission() async {
    try {
      final bool result =
          await _methodChannel.invokeMethod('hasAccessibilityPermission');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error checking accessibility permission: ${e.message}');
      }
      return false;
    }
  }

  /// Request accessibility service permission from user
  /// Opens Android Accessibility Settings for manual enablement
  static Future<bool> requestAccessibilityPermission() async {
    try {
      final bool result =
          await _methodChannel.invokeMethod('requestAccessibilityPermission');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error requesting accessibility permission: ${e.message}');
      }
      return false;
    }
  }

  /// Start the overlay service
  static Future<bool> startOverlayService() async {
    try {
      final bool result =
          await _methodChannel.invokeMethod('startOverlayService');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error starting overlay service: ${e.message}');
      }
      return false;
    }
  }

  /// Check and request overlay permission if needed
  static Future<bool> ensureOverlayPermission() async {
    bool hasPermission = await hasOverlayPermission();
    if (!hasPermission) {
      hasPermission = await requestOverlayPermission();
    }
    return hasPermission;
  }

  /// Check and request accessibility permission if needed
  static Future<bool> ensureAccessibilityPermission() async {
    bool hasPermission = await hasAccessibilityPermission();
    if (!hasPermission) {
      hasPermission = await requestAccessibilityPermission();
    }
    return hasPermission;
  }

  /// Stop the overlay service
  static Future<bool> stopOverlayService() async {
    try {
      final bool result =
          await _methodChannel.invokeMethod('stopOverlayService');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error stopping overlay service: ${e.message}');
      }
      return false;
    }
  }

  /// Check if overlay service is currently running
  static Future<bool> isOverlayServiceRunning() async {
    try {
      final bool result =
          await _methodChannel.invokeMethod('isOverlayServiceRunning');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error checking overlay service status: ${e.message}');
      }
      return false;
    }
  }

  /// Send selected content and action to native side for processing
  static Future<bool> processAction({
    required String selectedContent,
    required String userIntent,
    required String action,
  }) async {
    try {
      final Map<String, dynamic> arguments = {
        'selectedContent': selectedContent,
        'userIntent': userIntent,
        'action': action,
      };

      final bool result =
          await _methodChannel.invokeMethod('processAction', arguments);
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error processing action: ${e.message}');
      }
      return false;
    }
  }

  /// Get current device information for fingerprint generation
  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      final Map<dynamic, dynamic> result =
          await _methodChannel.invokeMethod('getDeviceInfo');
      return Map<String, String>.from(result);
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error getting device info: ${e.message}');
      }
      return {};
    }
  }

  /// Setup listener for selected text events from Accessibility Service
  static void _setupSelectedTextListener() {
    _selectedTextController = StreamController<String>.broadcast();

    _selectedTextChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is String) {
          _selectedTextController?.add(event);
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('Selected text stream error: $error');
        }
      },
    );
  }

  /// Stream of selected text from other apps
  static Stream<String> get selectedTextStream {
    if (_selectedTextController == null) {
      _setupSelectedTextListener();
    }
    return _selectedTextController!.stream;
  }

  /// Clean up resources
  static void dispose() {
    _selectedTextController?.close();
    _selectedTextController = null;
  }
}

/// Data class for selected content information
class SelectedContentInfo {
  final String content;
  final String packageName;
  final DateTime timestamp;

  const SelectedContentInfo({
    required this.content,
    required this.packageName,
    required this.timestamp,
  });

  factory SelectedContentInfo.fromMap(Map<String, dynamic> map) {
    return SelectedContentInfo(
      content: map['content'] ?? '',
      packageName: map['packageName'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'packageName': packageName,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

/// Usage example in Flutter widgets
class PlatformServiceUsageExample {
  /// Example of checking and requesting permissions
  static Future<void> initializePermissions() async {
    // Initialize the platform service
    await PlatformService.initialize();

    // Check overlay permission
    bool overlayPermission = await PlatformService.ensureOverlayPermission();
    if (kDebugMode) {
      print('Overlay permission granted: $overlayPermission');
    }

    // Check accessibility permission
    bool accessibilityPermission =
        await PlatformService.ensureAccessibilityPermission();
    if (kDebugMode) {
      print('Accessibility permission granted: $accessibilityPermission');
    }

    // Start overlay service if permissions are granted
    if (overlayPermission && accessibilityPermission) {
      bool started = await PlatformService.startOverlayService();
      if (kDebugMode) {
        print('Overlay service started: $started');
      }
    }
  }

  /// Example of listening to selected text
  static void listenToSelectedText() {
    PlatformService.selectedTextStream.listen((String selectedText) {
      if (kDebugMode) {
        print('Selected text received: $selectedText');
      }
      // Process the selected text in your app
    });
  }

  /// Example of processing user action
  static Future<void> processUserAction(String selectedText) async {
    bool success = await PlatformService.processAction(
      selectedContent: selectedText,
      userIntent: 'Send to phone',
      action: 'cross_device_send',
    );

    if (kDebugMode) {
      print('Action processed successfully: $success');
    }
  }
}
