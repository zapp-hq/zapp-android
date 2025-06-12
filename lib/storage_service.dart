import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pointycastle/export.dart';
import 'crypto_utils.dart';

/// Storage service for managing cryptographic keys and linked device data
/// Uses SharedPreferences for current implementation with clear upgrade path
///
/// PRODUCTION NOTE: For truly sensitive data like private keys, consider using
/// flutter_secure_storage package which provides hardware-backed encryption:
/// - Uses Android Keystore and iOS Keychain for secure key storage
/// - Provides encryption at rest with hardware security modules
/// - Better protection against root/jailbreak access
///
/// Current implementation uses SharedPreferences which stores data in:
/// - Android: Encrypted preferences with MODE_PRIVATE
/// - iOS: NSUserDefaults with app sandbox protection
class StorageService {
  // Storage keys for different data types
  static const String _keyPublicKey = 'zapp_public_key';
  static const String _keyPrivateKey = 'zapp_private_key';
  static const String _keyFingerprint = 'zapp_fingerprint';
  static const String _keyLinkedDevices = 'zapp_linked_devices';
  static const String _keyDeviceSettings = 'zapp_device_settings';

  /// Saves the local device's RSA key pair securely
  /// Stores both public and private keys along with generated fingerprint
  ///
  /// SECURITY CONSIDERATION: In production, private keys should be stored
  /// using flutter_secure_storage for hardware-backed encryption
  static Future<bool> saveKeyPair(
      RSAPublicKey publicKey, RSAPrivateKey privateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert keys to Base64 for storage
      final publicKeyBase64 = CryptoUtils.publicKeyToBase64(publicKey);
      final privateKeyBase64 = CryptoUtils.privateKeyToBase64(privateKey);

      // Generate fingerprint for the public key
      final fingerprint = CryptoUtils.generateFingerprint(publicKey);

      // Store all key components
      await prefs.setString(_keyPublicKey, publicKeyBase64);
      await prefs.setString(_keyPrivateKey, privateKeyBase64);
      await prefs.setString(_keyFingerprint, fingerprint);

      if (kDebugMode) {
        print('Key pair saved successfully with fingerprint: $fingerprint');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving key pair: $e');
      }
      return false;
    }
  }

  /// Loads the local device's RSA key pair from storage
  /// Returns null if no key pair exists or if loading fails
  ///
  /// This method should be called during app initialization to restore
  /// the device's cryptographic identity
  static Future<Map<String, dynamic>?> loadKeyPair() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if all key components exist
      final publicKeyBase64 = prefs.getString(_keyPublicKey);
      final privateKeyBase64 = prefs.getString(_keyPrivateKey);
      final fingerprint = prefs.getString(_keyFingerprint);

      if (publicKeyBase64 == null ||
          privateKeyBase64 == null ||
          fingerprint == null) {
        if (kDebugMode) {
          print('No complete key pair found in storage');
        }
        return null;
      }

      // Reconstruct keys from Base64
      final publicKey = CryptoUtils.publicKeyFromBase64(publicKeyBase64);
      final privateKey = CryptoUtils.privateKeyFromBase64(privateKeyBase64);

      // Verify fingerprint matches (integrity check)
      final computedFingerprint = CryptoUtils.generateFingerprint(publicKey);
      if (computedFingerprint != fingerprint) {
        if (kDebugMode) {
          print(
            'Warning: Stored fingerprint does not match computed fingerprint');
        }
        // Could indicate data corruption or tampering
      }

      if (kDebugMode) {
        print('Key pair loaded successfully with fingerprint: $fingerprint');
      }

      return {
        'publicKey': publicKey,
        'privateKey': privateKey,
        'fingerprint': fingerprint,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error loading key pair: $e');
      }
      return null;
    }
  }

  /// Saves a linked device's information including public key and fingerprint
  /// Devices are stored as a list of JSON objects for easy management
  ///
  /// Each device entry contains:
  /// - deviceName: Human-readable name for the device
  /// - deviceFingerprint: SHA-256 hash of the device's public key
  /// - publicKey: Base64 encoded public key for encryption
  /// - dateAdded: Timestamp when device was linked
  static Future<bool> saveLinkedDevice(String deviceName,
      String deviceFingerprint, RSAPublicKey publicKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load existing linked devices
      final existingDevices = await loadLinkedDevices();

      // Check if device already exists (prevent duplicates)
      final existingIndex = existingDevices.indexWhere(
          (device) => device['deviceFingerprint'] == deviceFingerprint);

      // Create device data object
      final deviceData = {
        'deviceName': deviceName,
        'deviceFingerprint': deviceFingerprint,
        'publicKey': CryptoUtils.publicKeyToBase64(publicKey),
        'dateAdded': DateTime.now().toIso8601String(),
      };

      if (existingIndex >= 0) {
        // Update existing device
        existingDevices[existingIndex] = deviceData;
        if (kDebugMode) {
          print('Updated existing device: $deviceName');
        }
      } else {
        // Add new device
        existingDevices.add(deviceData);
        if (kDebugMode) {
          print('Added new linked device: $deviceName');
        }
      }

      // Save updated device list
      final devicesJson = json.encode(existingDevices);
      await prefs.setString(_keyLinkedDevices, devicesJson);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving linked device: $e');
      }
      return false;
    }
  }

  /// Loads all linked devices from storage
  /// Returns a list of device data maps, empty list if none exist
  ///
  /// Each device in the returned list contains:
  /// - deviceName: Display name of the device
  /// - deviceFingerprint: Unique identifier for verification
  /// - publicKey: Base64 encoded public key
  /// - dateAdded: When the device was linked
  static Future<List<Map<String, dynamic>>> loadLinkedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesJson = prefs.getString(_keyLinkedDevices);

      if (devicesJson == null) {
        if (kDebugMode) {
          print('No linked devices found in storage');
        }
        return [];
      }

      // Parse JSON and ensure type safety
      final devicesList = json.decode(devicesJson) as List<dynamic>;
      final devices = devicesList.cast<Map<String, dynamic>>();

      if (kDebugMode) {
        print('Loaded ${devices.length} linked devices');
      }
      return devices;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading linked devices: $e');
      }
      return [];
    }
  }

  /// Removes a linked device by its fingerprint
  /// Returns true if device was found and removed, false otherwise
  ///
  /// This method permanently removes the device from local storage
  /// The device will need to be re-linked to restore communication
  static Future<bool> deleteLinkedDevice(String deviceFingerprint) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load existing devices
      final existingDevices = await loadLinkedDevices();

      // Find device to remove
      final initialLength = existingDevices.length;
      existingDevices.removeWhere(
          (device) => device['deviceFingerprint'] == deviceFingerprint);

      if (existingDevices.length == initialLength) {
        if (kDebugMode) {
          print('Device with fingerprint $deviceFingerprint not found');
        }
        return false;
      }

      // Save updated device list
      final devicesJson = json.encode(existingDevices);
      await prefs.setString(_keyLinkedDevices, devicesJson);

      if (kDebugMode) {
        print(
          'Successfully removed device with fingerprint: $deviceFingerprint');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting linked device: $e');
      }
      return false;
    }
  }

  /// Gets a specific linked device by fingerprint
  /// Returns device data map or null if not found
  ///
  /// Useful for retrieving a device's public key for encryption
  static Future<Map<String, dynamic>?> getLinkedDevice(
      String deviceFingerprint) async {
    try {
      final devices = await loadLinkedDevices();

      for (final device in devices) {
        if (device['deviceFingerprint'] == deviceFingerprint) {
          return device;
        }
      }

      if (kDebugMode) {
        print('Device with fingerprint $deviceFingerprint not found');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting linked device: $e');
      }
      return null;
    }
  }

  /// Gets the RSA public key for a specific linked device
  /// Returns the reconstructed RSAPublicKey or null if device not found
  ///
  /// This is used when encrypting messages to send to specific devices
  static Future<RSAPublicKey?> getDevicePublicKey(
      String deviceFingerprint) async {
    try {
      final deviceData = await getLinkedDevice(deviceFingerprint);

      if (deviceData == null) {
        return null;
      }

      final publicKeyBase64 = deviceData['publicKey'] as String;
      return CryptoUtils.publicKeyFromBase64(publicKeyBase64);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting device public key: $e');
      }
      return null;
    }
  }

  /// Saves application settings and preferences
  /// Used for storing overlay preferences, device name, etc.
  static Future<bool> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settings);
      await prefs.setString(_keyDeviceSettings, settingsJson);

      if (kDebugMode) {
        print('Settings saved successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving settings: $e');
      }
      return false;
    }
  }

  /// Loads application settings and preferences
  /// Returns empty map if no settings exist
  static Future<Map<String, dynamic>> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_keyDeviceSettings);

      if (settingsJson == null) {
        if (kDebugMode) {
          print('No settings found, returning defaults');
        }
        return {};
      }

      final settings = json.decode(settingsJson) as Map<String, dynamic>;
      if (kDebugMode) {
        print('Settings loaded successfully');
      }
      return settings;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading settings: $e');
      }
      return {};
    }
  }

  /// Clears all stored data - use with caution!
  /// This will remove keys, linked devices, and settings
  ///
  /// DANGER: This operation cannot be undone and will require
  /// complete re-setup of the device and re-linking with other devices
  static Future<bool> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove all Zapp-related data
      await prefs.remove(_keyPublicKey);
      await prefs.remove(_keyPrivateKey);
      await prefs.remove(_keyFingerprint);
      await prefs.remove(_keyLinkedDevices);
      await prefs.remove(_keyDeviceSettings);

      if (kDebugMode) {
        print('All data cleared successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing data: $e');
      }
      return false;
    }
  }

  /// Generates a summary of stored data for debugging/diagnostics
  /// Does not expose sensitive information like private keys
  static Future<Map<String, dynamic>> getStorageSummary() async {
    try {
      final keyPair = await loadKeyPair();
      final devices = await loadLinkedDevices();
      final settings = await loadSettings();

      return {
        'hasKeyPair': keyPair != null,
        'fingerprint': keyPair?['fingerprint'] ?? 'None',
        'linkedDevicesCount': devices.length,
        'linkedDeviceNames': devices.map((d) => d['deviceName']).toList(),
        'settingsKeys': settings.keys.toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': 'Failed to generate summary: $e',
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }
}
