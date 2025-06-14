/// Cryptographic utility class for hybrid RSA-AES-GCM encryption
/// Implements end-to-end encryption using RSA for key wrapping and signatures
/// with AES-GCM for efficient content encryption
/// Uses the pointycastle package for all cryptographic operations
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// Cryptographic utility class for RSA encryption, decryption, signing, and verification
/// Uses the pointycastle package for all cryptographic operations
class CryptoUtils {
  /// Generates an RSA public/private key pair with the specified bit length
  /// Returns an AsymmetricKeyPair containing both RSA public and private keys
  /// Default bit length is 2048 for good security vs performance balance
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateKeyPair(
      {int bitLength = 2048}) {
    // Create a secure random number generator
    final secureRandom = _createSecureRandom();

    // Create RSA key generator parameters
    // Using public exponent 65537 (0x10001) which is standard and secure
    final rsaParams = RSAKeyGeneratorParameters(
        BigInt.parse('65537'), // Standard public exponent
        bitLength, // Key size in bits (2048, 3072, 4096)
        64 // Certainty parameter for prime generation
        );

    // Create parameter object that includes random number generator
    final paramsWithRandom = ParametersWithRandom(rsaParams, secureRandom);

    // Initialize the key generator
    final keyGenerator = RSAKeyGenerator();
    keyGenerator.init(paramsWithRandom);

    // Generate the key pair and cast to proper types
    final keyPair = keyGenerator.generateKeyPair();
    final publicKey = keyPair.publicKey as RSAPublicKey;
    final privateKey = keyPair.privateKey as RSAPrivateKey;

    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
        publicKey, privateKey);
  }

  /// Generates a random AES key for symmetric encryption
  /// Default key length is 32 bytes (256 bits) for AES-256
  /// Returns a cryptographically secure random key
  static Uint8List generateAesKey({int keyLengthBytes = 32}) {
    final secureRandom = _createSecureRandom();
    final keyBytes = Uint8List(keyLengthBytes);
    secureRandom.nextBytes(keyBytes as int);
    return keyBytes;
  }

  /// Generates a random Initialization Vector (IV) for AES-GCM
  /// Default IV length is 12 bytes (96 bits) which is standard for GCM
  /// Returns a cryptographically secure random IV
  static Uint8List generateAesIv({int ivLengthBytes = 12}) {
    final secureRandom = _createSecureRandom();
    final ivBytes = Uint8List(ivLengthBytes);
    secureRandom.nextBytes(ivBytes as int);
    return ivBytes;
  }

  /// Encrypts data using AES-GCM authenticated encryption
  /// Provides both confidentiality and authenticity of the data
  /// Associated data can be included for additional authentication context
  static Uint8List aesGcmEncrypt(
      Uint8List plaintext, Uint8List key, Uint8List iv,
      {Uint8List? associatedData}) {
    try {
      final cipher = GCMBlockCipher(AESEngine());
      final keyParam = KeyParameter(key);
      final params = AEADParameters(
        keyParam,
        128, // Authentication tag length in bits (128 bits = 16 bytes)
        iv,
        associatedData ?? Uint8List(0),
      );

      cipher.init(true, params); // True for encryption
      return cipher.process(plaintext);
    } catch (e) {
      throw Exception('AES-GCM encryption failed: $e');
    }
  }

  /// Decrypts data using AES-GCM authenticated encryption
  /// Verifies both the ciphertext and authentication tag
  /// Throws exception if authentication fails
  static Uint8List aesGcmDecrypt(
      Uint8List ciphertext, Uint8List key, Uint8List iv,
      {Uint8List? associatedData}) {
    try {
      final cipher = GCMBlockCipher(AESEngine());
      final keyParam = KeyParameter(key);
      final params = AEADParameters(
        keyParam,
        128, // Authentication tag length in bits
        iv,
        associatedData ?? Uint8List(0),
      );

      cipher.init(false, params); // False for decryption
      return cipher.process(ciphertext);
    } catch (e) {
      throw Exception('AES-GCM decryption failed: $e');
    }
  }

  /// Encrypts a string message using hybrid RSA-AES-GCM scheme
  /// 1. Generates ephemeral AES key and IV
  /// 2. Encrypts message content with AES-GCM
  /// 3. Encrypts AES key with recipient's RSA public key
  /// 4. Signs the encrypted payload with sender's RSA private key
  /// Returns a JSON string containing all encrypted components
  static String encryptHybridMessage(
      String message, RSAPublicKey recipientPublicKey, RSAPrivateKey senderPrivateKey) {
    try {
      // 1. Generate ephemeral AES key and IV
      final aesKey = generateAesKey();
      final aesIv = generateAesIv();

      // 2. Encrypt the message content with AES-GCM
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final encryptedContent = aesGcmEncrypt(messageBytes, aesKey, aesIv);

      // 3. Encrypt the ephemeral AES key with recipient's RSA public key (OAEP padding)
      final rsaEncryptor = OAEPEncoding.withSHA256(RSAEngine());
      rsaEncryptor.init(true, PublicKeyParameter<RSAPublicKey>(recipientPublicKey));
      final encryptedAesKey = _processInBlocks(rsaEncryptor, aesKey);

      // 4. Create payload for signing (encrypted content + IV + encrypted AES key)
      final dataToSign = Uint8List.fromList(
          encryptedContent.toList() + aesIv.toList() + encryptedAesKey.toList());
      final signature = signBytes(dataToSign, senderPrivateKey);

      // 5. Bundle everything into a JSON string
      final Map<String, dynamic> encryptedBlob = {
        'encryptedAesKey': base64.encode(encryptedAesKey),
        'encryptedContent': base64.encode(encryptedContent),
        'iv': base64.encode(aesIv),
        'signature': base64.encode(signature),
        'version': '1.0', // For future compatibility
      };

      return json.encode(encryptedBlob);
    } catch (e) {
      throw Exception('Hybrid encryption failed: $e');
    }
  }

  /// Decrypts a hybrid RSA-AES-GCM encrypted message
  /// 1. Parses the JSON blob to extract components
  /// 2. Verifies digital signature for authenticity
  /// 3. Decrypts AES key using local RSA private key
  /// 4. Decrypts message content using recovered AES key
  /// Returns the original message string
  static String decryptHybridMessage(
      String jsonBlob, RSAPrivateKey localPrivateKey, RSAPublicKey senderPublicKey) {
    try {
      // Parse the JSON blob
      final Map<String, dynamic> blob = json.decode(jsonBlob) as Map<String, dynamic>;

      final encryptedAesKey = base64.decode(blob['encryptedAesKey'] as String);
      final encryptedContent = base64.decode(blob['encryptedContent'] as String);
      final aesIv = base64.decode(blob['iv'] as String);
      final signature = base64.decode(blob['signature'] as String);

      // 1. Verify the digital signature first (critical for authenticity)
      final dataToVerify = Uint8List.fromList(
          encryptedContent.toList() + aesIv.toList() + encryptedAesKey.toList());
      if (!verifyBytesSignature(dataToVerify, signature, senderPublicKey)) {
        throw const FormatException('Signature verification failed. Message authenticity compromised.');
      }

      // 2. Decrypt the ephemeral AES key with local RSA private key
      final rsaDecryptor = OAEPEncoding.withSHA256(RSAEngine());
      rsaDecryptor.init(false, PrivateKeyParameter<RSAPrivateKey>(localPrivateKey));
      final aesKey = _processInBlocks(rsaDecryptor, encryptedAesKey);

      // 3. Decrypt the message content with the ephemeral AES key
      final decryptedContentBytes = aesGcmDecrypt(encryptedContent, aesKey, aesIv);

      return utf8.decode(decryptedContentBytes);
    } catch (e) {
      throw Exception('Hybrid decryption failed: $e');
    }
  }

  /// Legacy method for backward compatibility
  /// @deprecated Use encryptHybridMessage instead
  static Uint8List encryptMessage(String message, RSAPublicKey publicKey) {
    final messageBytes = Uint8List.fromList(utf8.encode(message));
    final encryptor = OAEPEncoding.withSHA256(RSAEngine());
    encryptor.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    return _processInBlocks(encryptor, messageBytes);
  }

  /// Legacy method for backward compatibility
  /// @deprecated Use decryptHybridMessage instead
  static String decryptMessage(Uint8List encryptedBytes, RSAPrivateKey privateKey) {
    final decryptor = OAEPEncoding.withSHA256(RSAEngine());
    decryptor.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final decryptedBytes = _processInBlocks(decryptor, encryptedBytes);
    return utf8.decode(decryptedBytes);
  }

  /// Creates a digital signature for the provided message string
  /// Uses SHA-256 for hashing and RSA-PSS for signing
  /// Returns the signature as a base64-encoded string
  static String signMessage(String message, RSAPrivateKey privateKey) {
    final messageBytes = Uint8List.fromList(utf8.encode(message));
    final signature = signBytes(messageBytes, privateKey);
    return base64.encode(signature);
  }

  /// Creates a digital signature for byte array data
  /// Uses SHA-256 digest with RSA signing
  /// Returns raw signature bytes
  static Uint8List signBytes(Uint8List bytes, RSAPrivateKey privateKey) {
    try {
      final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
      signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
      final signature = signer.generateSignature(bytes);
      return signature.bytes;
    } catch (e) {
      throw Exception('Signing failed: $e');
    }
  }

  /// Verifies a digital signature for a message string
  /// Uses SHA-256 for hashing and RSA for verification
  /// Returns true if signature is valid, false otherwise
  static bool verifySignature(
      String message, String signature, RSAPublicKey publicKey) {
    try {
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final signatureBytes = base64.decode(signature);
      return verifyBytesSignature(messageBytes, signatureBytes, publicKey);
    } catch (e) {
      return false;
    }
  }

  /// Verifies a digital signature for byte array data
  /// Uses SHA-256 digest with RSA verification
  /// Returns true if signature is valid, false otherwise
  static bool verifyBytesSignature(
      Uint8List bytes, Uint8List signature, RSAPublicKey publicKey) {
    try {
      final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');
      verifier.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));
      final rsaSignature = RSASignature(signature);
      return verifier.verifySignature(bytes, rsaSignature);
    } catch (e) {
      return false;
    }
  }

  /// Converts RSA public key to Base64 encoded JSON string for storage/transmission
  /// Includes modulus and exponent components
  /// Returns a Base64 encoded string that can be safely stored or transmitted
  static String publicKeyToBase64(RSAPublicKey publicKey) {
    try {
      final keyData = {
        'modulus': publicKey.modulus.toString(),
        'exponent': publicKey.exponent.toString(),
        'keyType': 'RSA',
        'version': '1.0',
      };
      final jsonString = json.encode(keyData);
      return base64.encode(utf8.encode(jsonString));
    } catch (e) {
      throw Exception('Public key serialization failed: $e');
    }
  }

  /// Converts RSA private key to Base64 encoded JSON string for storage
  /// Includes all necessary components for key reconstruction
  /// WARNING: Store securely using flutter_secure_storage in production
  static String privateKeyToBase64(RSAPrivateKey privateKey) {
    try {
      final keyData = {
        'modulus': privateKey.modulus.toString(),
        'privateExponent': privateKey.privateExponent.toString(),
        'p': privateKey.p.toString(),
        'q': privateKey.q.toString(),
        'keyType': 'RSA',
        'version': '1.0',
      };
      final jsonString = json.encode(keyData);
      return base64.encode(utf8.encode(jsonString));
    } catch (e) {
      throw Exception('Private key serialization failed: $e');
    }
  }

  /// Reconstructs RSA public key from Base64 encoded JSON string
  /// Validates key format and components before reconstruction
  /// Throws FormatException if key format is invalid
  static RSAPublicKey publicKeyFromBase64(String base64Key) {
    try {
      final jsonString = utf8.decode(base64.decode(base64Key));
      final keyData = json.decode(jsonString) as Map<String, dynamic>;
      
      // Validate key format
      if (keyData['keyType'] != 'RSA') {
        throw const FormatException('Invalid key type. Expected RSA.');
      }
      
      final modulus = BigInt.parse(keyData['modulus'] as String);
      final exponent = BigInt.parse(keyData['exponent'] as String);
      
      return RSAPublicKey(modulus, exponent);
    } catch (e) {
      throw FormatException('Invalid public key format: $e');
    }
  }

  /// Reconstructs RSA private key from Base64 encoded JSON string
  /// Validates key format and components before reconstruction
  /// Throws FormatException if key format is invalid
  static RSAPrivateKey privateKeyFromBase64(String base64Key) {
    try {
      final jsonString = utf8.decode(base64.decode(base64Key));
      final keyData = json.decode(jsonString) as Map<String, dynamic>;
      
      // Validate key format
      if (keyData['keyType'] != 'RSA') {
        throw const FormatException('Invalid key type. Expected RSA.');
      }
      
      final modulus = BigInt.parse(keyData['modulus'] as String);
      final privateExponent = BigInt.parse(keyData['privateExponent'] as String);
      final p = BigInt.parse(keyData['p'] as String);
      final q = BigInt.parse(keyData['q'] as String);
      
      return RSAPrivateKey(modulus, privateExponent, p, q);
    } catch (e) {
      throw FormatException('Invalid private key format: $e');
    }
  }

  /// Generates SHA-256 fingerprint of an RSA public key
  /// Used for device identification and verification
  /// Returns a hexadecimal string representation of the hash
  static String generateFingerprint(RSAPublicKey publicKey) {
    try {
      // Convert public key to standard format for fingerprinting
      final keyString = publicKeyToBase64(publicKey);

      // Create SHA-256 digest
      final digest = SHA256Digest();
      final keyBytes = Uint8List.fromList(utf8.encode(keyString));
      final hashBytes = digest.process(keyBytes);

      // Convert to hexadecimal string with colons (SSH-style format)
      final hexString = hashBytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join(':');
      return hexString.toUpperCase();
    } catch (e) {
      throw Exception('Fingerprint generation failed: $e');
    }
  }

  /// Creates a secure random number generator seeded with cryptographically strong entropy
  /// Uses Fortuna random number generator with proper seeding
  static SecureRandom _createSecureRandom() {
    final secureRandom = FortunaRandom();

    // Generate cryptographically secure seed
    final seedSource = Random.secure();
    final seeds = <int>[];
    for (int i = 0; i < 32; i++) {
      seeds.add(seedSource.nextInt(256));
    }

    // Seed the random number generator
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    return secureRandom;
  }

  /// Processes encryption/decryption in blocks to handle large data
  /// RSA can only encrypt/decrypt data smaller than the key size
  /// Automatically handles block size limitations and padding
  static Uint8List _processInBlocks(
      AsymmetricBlockCipher cipher, Uint8List input) {
    try {
      final numBlocks = input.length ~/ cipher.inputBlockSize +
          ((input.length % cipher.inputBlockSize != 0) ? 1 : 0);

      // Create output buffer
      final output = Uint8List(numBlocks * cipher.outputBlockSize);

      var inputOffset = 0;
      var outputOffset = 0;

      // Process each block
      while (inputOffset < input.length) {
        final chunkSize = (inputOffset + cipher.inputBlockSize <= input.length)
            ? cipher.inputBlockSize
            : input.length - inputOffset;

        outputOffset += cipher.processBlock(
            input, inputOffset, chunkSize, output, outputOffset);
        inputOffset += chunkSize;
      }

      // Return trimmed output if necessary
      return (output.length == outputOffset)
          ? output
          : output.sublist(0, outputOffset);
    } catch (e) {
      throw Exception('Block processing failed: $e');
    }
  }

  /// Utility method to test hybrid encryption round-trip
  /// For development and testing purposes only
  static bool testHybridEncryption() {
    try {
      // Generate test key pairs
      final senderKeyPair = generateKeyPair();
      final recipientKeyPair = generateKeyPair();
      
      const testMessage = 'This is a test message for hybrid encryption!';
      
      // Encrypt message
      final encryptedBlob = encryptHybridMessage(
        testMessage,
        recipientKeyPair.publicKey,
        senderKeyPair.privateKey,
      );
      
      // Decrypt message
      final decryptedMessage = decryptHybridMessage(
        encryptedBlob,
        recipientKeyPair.privateKey,
        senderKeyPair.publicKey,
      );
      
      return decryptedMessage == testMessage;
    } catch (e) {
      return false;
    }
  }
}

/// Helper class for structured error handling in cryptographic operations
class CryptoException implements Exception {
  final String message;
  final String? code;
  final Exception? innerException;

  const CryptoException(this.message, {this.code, this.innerException});

  @override
  String toString() => 'CryptoException: $message ${code != null ? '($code)' : ''}';
}

/// Performance metrics for cryptographic operations
class CryptoMetrics {
  final Duration keyGenerationTime;
  final Duration encryptionTime;
  final Duration decryptionTime;
  final int messageSize;

  const CryptoMetrics({
    required this.keyGenerationTime,
    required this.encryptionTime,
    required this.decryptionTime,
    required this.messageSize,
  });

  @override
  String toString() {
    return 'CryptoMetrics{keyGen: ${keyGenerationTime.inMilliseconds}ms, '
           'encrypt: ${encryptionTime.inMilliseconds}ms, '
           'decrypt: ${decryptionTime.inMilliseconds}ms, '
           'size: ${messageSize}B}';
  }
}