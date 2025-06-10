import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'setup_screen.dart';
import 'home_screen.dart';
import 'action_selection_screen.dart';
import 'zapp_overlay.dart';

void main() {
  runApp(const ZappApp());
}

class ZappApp extends StatelessWidget {
  const ZappApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zapp!',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
      ),
      home: const AppInitializer(),

      // Define named routes for better navigation management
      routes: {
        '/home': (context) => const HomeScreen(),
        '/action-selection': (context) => const ActionSelectionScreen(),
      },

      // Handle deep links and navigation
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/action-selection':
            return MaterialPageRoute(
              builder: (context) => const ActionSelectionScreen(),
              fullscreenDialog: true,
              settings: settings,
            );
          default:
            return null;
        }
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({Key? key}) : super(key: key);

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _hasCompletedSetup = false;
  String _initializationStatus = 'Starting Zapp...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initialize the application and check setup status
  Future<void> _initializeApp() async {
    try {
      setState(() {
        _initializationStatus = 'Checking device setup...';
      });

      // Check if the app has been set up before
      final prefs = await SharedPreferences.getInstance();
      final hasSetupCompleted = prefs.getBool('setup_completed') ?? false;

      setState(() {
        _initializationStatus = 'Loading PGP keys...';
      });

      // Check if PGP keys exist
      final hasPrivateKey = prefs.getString('local_private_key') != null;
      final hasPublicKey = prefs.getString('local_public_key') != null;

      setState(() {
        _initializationStatus = 'Initializing overlay system...';
      });

      // Initialize overlay system early for better user experience
      await ZappOverlayManager.initialize(context);

      setState(() {
        _initializationStatus = 'Ready!';
      });

      // Short delay to show the ready message
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _hasCompletedSetup = hasSetupCompleted && hasPrivateKey && hasPublicKey;
        _isLoading = false;
      });
    } catch (e) {
      print('Error during app initialization: $e');
      setState(() {
        _initializationStatus = 'Error during initialization';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue, Colors.purple],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.flash_on, size: 80, color: Colors.white),
                const SizedBox(height: 24),
                const Text(
                  'Zapp!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),
                Text(
                  _initializationStatus,
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Navigate to appropriate screen based on setup status
    if (_hasCompletedSetup) {
      return const HomeScreen();
    } else {
      return const SetupScreen();
    }
  }
}

/// Global app configuration and constants
class ZappConfig {
  static const String appName = 'Zapp!';
  static const String appVersion = '1.0.0';

  // Method channel names for native integration
  static const String overlayChannelName = 'com.zapp.overlay/control';
  static const String accessibilityChannelName =
      'com.zapp.accessibility/content';
  static const String cryptoChannelName = 'com.zapp.crypto/operations';

  // Shared preferences keys
  static const String setupCompletedKey = 'setup_completed';
  static const String overlayEnabledKey = 'overlay_enabled';
  static const String linkedDevicesKey = 'linked_devices';
  static const String localPrivateKeyKey = 'local_private_key';
  static const String localPublicKeyKey = 'local_public_key';
  static const String localFingerprintKey = 'local_fingerprint';

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double cardElevation = 2.0;
  static const Duration animationDuration = Duration(milliseconds: 300);

  // Colors
  static const Color primaryColor = Colors.blue;
  static const Color accentColor = Colors.orange;
  static const Color successColor = Colors.green;
  static const Color errorColor = Colors.red;
  static const Color warningColor = Colors.orange;
}

/// Error handling and logging utilities
class ZappLogger {
  static void info(String message) {
    print('[ZAPP INFO] $message');
  }

  static void warning(String message) {
    print('[ZAPP WARNING] $message');
  }

  static void error(String message, [Object? error]) {
    print('[ZAPP ERROR] $message');
    if (error != null) {
      print('[ZAPP ERROR] Details: $error');
    }
  }

  static void debug(String message) {
    // Only log debug messages in debug mode
    assert(() {
      print('[ZAPP DEBUG] $message');
      return true;
    }());
  }
}

/// Navigation helper utilities
class ZappNavigation {
  /// Navigate to Action Selection Screen from anywhere in the app
  static Future<void> openActionSelection(BuildContext context) async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ActionSelectionScreen(),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      ZappLogger.error('Failed to navigate to Action Selection Screen', e);
    }
  }

  /// Navigate to Home Screen and clear navigation stack
  static Future<void> navigateToHome(BuildContext context) async {
    try {
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      ZappLogger.error('Failed to navigate to Home Screen', e);
    }
  }
}

/// Global utilities for the Zapp application
class ZappUtils {
  /// Format timestamp for user-friendly display
  static String formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  /// Truncate text with ellipsis
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Generate a simple device fingerprint for display
  static String generateDisplayFingerprint(String fullFingerprint) {
    if (fullFingerprint.length < 16) return fullFingerprint;
    return '${fullFingerprint.substring(0, 8)}...${fullFingerprint.substring(fullFingerprint.length - 8)}';
  }

  /// Validate if a string looks like a PGP fingerprint
  static bool isValidFingerprint(String fingerprint) {
    // Simple validation - should be hexadecimal and reasonable length
    final regex = RegExp(r'^[A-Fa-f0-9]{16,}$');
    return regex.hasMatch(fingerprint.replaceAll(' ', ''));
  }
}
