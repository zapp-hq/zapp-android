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

  /// Encrypts a string message using the recipient's RSA public key
  /// Uses OAEP padding with SHA-256 for enhanced security
  /// Returns encrypted data as Uint8List that should be Base64 encoded for storage/transmission
  static Uint8List encryptMessage(String message, RSAPublicKey publicKey) {
    // Create OAEP encoding with SHA-256 digest for secure padding
    final encryptor = OAEPEncoding.withSHA256(RSAEngine());

    // Initialize for encryption with the public key
    encryptor.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    // Convert message to bytes and encrypt
    final messageBytes = Uint8List.fromList(utf8.encode(message));

    // Process the encryption in blocks if necessary
    return _processInBlocks(encryptor, messageBytes);
  }

  /// Decrypts encrypted bytes using the local RSA private key
  /// Uses OAEP padding with SHA-256 matching the encryption process
  /// Returns the original message as a string
  static String decryptMessage(
      Uint8List encryptedBytes, RSAPrivateKey privateKey) {
    // Create OAEP encoding with SHA-256 digest matching encryption
    final decryptor = OAEPEncoding.withSHA256(RSAEngine());

    // Initialize for decryption with the private key
    decryptor.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    // Decrypt the data and convert back to string
    final decryptedBytes = _processInBlocks(decryptor, encryptedBytes);
    return utf8.decode(decryptedBytes);
  }

  /// Signs a message using RSA private key with SHA-256 digest
  /// Creates a digital signature that can be verified with the corresponding public key
  /// Returns the signature as Uint8List
  static Uint8List signMessage(String message, RSAPrivateKey privateKey) {
    // Create RSA signer with SHA-256 digest
    // Algorithm identifier for SHA-256 with RSA encryption (RFC 3447)
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');

    // Initialize for signing with the private key
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    // Convert message to bytes and generate signature
    final messageBytes = Uint8List.fromList(utf8.encode(message));
    final signature = signer.generateSignature(messageBytes);

    return signature.bytes;
  }

  /// Verifies a signature using RSA public key with SHA-256 digest
  /// Checks if the signature was created by the holder of the corresponding private key
  /// Returns true if signature is valid, false otherwise
  static bool verifySignature(
      String message, Uint8List signature, RSAPublicKey publicKey) {
    try {
      // Create RSA verifier with SHA-256 digest (same as signing)
      final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');

      // Initialize for verification with the public key
      verifier.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

      // Convert message to bytes and create signature object
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final rsaSignature = RSASignature(signature);

      // Verify the signature
      return verifier.verifySignature(messageBytes, rsaSignature);
    } catch (e) {
      // Return false for any verification errors (corrupted signature, etc.)
      return false;
    }
  }

  /// Converts RSA public key to Base64 encoded string for storage/transmission
  /// Encodes the modulus and exponent in a custom format for easy parsing
  static String publicKeyToBase64(RSAPublicKey publicKey) {
    // Create a map with the key components
    final keyData = {
      'modulus': publicKey.modulus.toString(),
      'exponent': publicKey.exponent.toString(),
    };

    // Encode as JSON then Base64
    final jsonString = json.encode(keyData);
    return base64.encode(utf8.encode(jsonString));
  }

  /// Converts RSA private key to Base64 encoded string for secure storage
  /// Includes all necessary components for full key reconstruction
  static String privateKeyToBase64(RSAPrivateKey privateKey) {
    // Create a map with all private key components
    final keyData = {
      'modulus': privateKey.modulus.toString(),
      'privateExponent': privateKey.privateExponent.toString(),
      'p': privateKey.p.toString(),
      'q': privateKey.q.toString(),
    };

    // Encode as JSON then Base64
    final jsonString = json.encode(keyData);
    return base64.encode(utf8.encode(jsonString));
  }

  /// Reconstructs RSA public key from Base64 encoded string
  /// Parses the JSON format created by publicKeyToBase64
  static RSAPublicKey publicKeyFromBase64(String base64Key) {
    try {
      // Decode Base64 and parse JSON
      final jsonString = utf8.decode(base64.decode(base64Key));
      final keyData = json.decode(jsonString) as Map<String, dynamic>;

      // Extract components and create key
      final modulus = BigInt.parse(keyData['modulus'] as String);
      final exponent = BigInt.parse(keyData['exponent'] as String);

      return RSAPublicKey(modulus, exponent);
    } catch (e) {
      throw const FormatException('Invalid public key format: \$e');
    }
  }

  /// Reconstructs RSA private key from Base64 encoded string
  /// Parses the JSON format created by privateKeyToBase64
  static RSAPrivateKey privateKeyFromBase64(String base64Key) {
    try {
      // Decode Base64 and parse JSON
      final jsonString = utf8.decode(base64.decode(base64Key));
      final keyData = json.decode(jsonString) as Map<String, dynamic>;

      // Extract components and create key
      final modulus = BigInt.parse(keyData['modulus'] as String);
      final privateExponent =
          BigInt.parse(keyData['privateExponent'] as String);
      final p = BigInt.parse(keyData['p'] as String);
      final q = BigInt.parse(keyData['q'] as String);

      return RSAPrivateKey(modulus, privateExponent, p, q);
    } catch (e) {
      throw const FormatException('Invalid private key format: \$e');
    }
  }

  /// Generates SHA-256 fingerprint of an RSA public key
  /// Used for device identification and verification
  /// Returns a hexadecimal string representation of the hash
  static String generateFingerprint(RSAPublicKey publicKey) {
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
  static Uint8List _processInBlocks(
      AsymmetricBlockCipher cipher, Uint8List input) {
    // Calculate number of blocks needed
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
  }
}
