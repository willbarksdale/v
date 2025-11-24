import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/cupertino.dart';
import 'ssh.dart';
import 'terminal.dart';
import 'preview.dart';

// ============================================================================
// NATIVE SSH SCREEN BRIDGE
// ============================================================================
// Manages the native Swift UI SSH login screen and handles callbacks

class NativeSSHScreen {
  static const MethodChannel _channel = MethodChannel('native_ssh_screen');
  static bool _isInitialized = false;
  
  // Callback handlers
  static Function(String ip, String port, String username, String password, String privateKey, String privateKeyPassphrase)? _onConnectTapped;
  static Function()? _onLoadCredentials;
  
  /// Initialize the native SSH screen bridge
  static Future<void> initialize({
    required Function(String ip, String port, String username, String password, String privateKey, String privateKeyPassphrase) onConnectTapped,
    required Function() onLoadCredentials,
  }) async {
    if (_isInitialized) return;
    
    _onConnectTapped = onConnectTapped;
    _onLoadCredentials = onLoadCredentials;
    
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onConnectTapped':
          final args = call.arguments as Map;
          _onConnectTapped?.call(
            args['ip'] ?? '',
            args['port'] ?? '22',
            args['username'] ?? '',
            args['password'] ?? '',
            args['privateKey'] ?? '',
            args['privateKeyPassphrase'] ?? '',
          );
          break;
        case 'onLoadCredentials':
          _onLoadCredentials?.call();
          break;
      }
    });
    
    _isInitialized = true;
    debugPrint('✅ Native SSH screen bridge initialized');
  }
  
  /// Show the native SSH login screen
  static Future<bool> show() async {
    try {
      final bool? result = await _channel.invokeMethod('showNativeSSHScreen');
      return result ?? false;
    } catch (e) {
      debugPrint('Error showing native SSH screen: $e');
      return false;
    }
  }
  
  /// Hide the native SSH login screen
  static Future<bool> hide() async {
    try {
      final bool? result = await _channel.invokeMethod('hideNativeSSHScreen');
      return result ?? false;
    } catch (e) {
      debugPrint('Error hiding native SSH screen: $e');
      return false;
    }
  }
  
  /// Load credentials into the native SSH screen
  static Future<bool> loadCredentials({
    required String ip,
    required String port,
    required String username,
    String? password,
    String? privateKey,
    String? privateKeyPassphrase,
  }) async {
    try {
      final bool? result = await _channel.invokeMethod('loadCredentials', {
        'ip': ip,
        'port': port,
        'username': username,
        'password': password ?? '',
        'privateKey': privateKey ?? '',
        'privateKeyPassphrase': privateKeyPassphrase ?? '',
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error loading credentials: $e');
      return false;
    }
  }
  
  /// Stop loading indicator
  static Future<bool> stopLoading() async {
    try {
      final bool? result = await _channel.invokeMethod('stopLoading');
      return result ?? false;
    } catch (e) {
      debugPrint('Error stopping loading: $e');
      return false;
    }
  }
  
  /// Show connection error alert
  static Future<bool> showConnectionError(String message) async {
    try {
      final bool? result = await _channel.invokeMethod('showConnectionError', {
        'message': message,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error showing connection error: $e');
      return false;
    }
  }
}

// ============================================================================
// NATIVE SSH MANAGER WIDGET
// ============================================================================
// Wraps the native SSH screen and manages its lifecycle

class NativeSSHManager extends ConsumerStatefulWidget {
  const NativeSSHManager({super.key});

  @override
  ConsumerState<NativeSSHManager> createState() => _NativeSSHManagerState();
}

class _NativeSSHManagerState extends ConsumerState<NativeSSHManager> {
  @override
  void initState() {
    super.initState();
    _initializeNativeScreen();
  }

  Future<void> _initializeNativeScreen() async {
    // Initialize the native SSH screen bridge
    await NativeSSHScreen.initialize(
      onConnectTapped: _handleConnectTapped,
      onLoadCredentials: _handleLoadCredentials,
    );
    
    // Set up Power button callback (button is shown by native SSH screen)
    LiquidGlassPowerButton.setOnPowerButtonTappedCallback(() {
      _handlePowerButtonTap();
    });
    
    // Show the native SSH screen (this will also show Power and Info buttons)
    await NativeSSHScreen.show();
    
    debugPrint('✅ Native SSH screen initialized and shown');
  }
  
  void _handlePowerButtonTap() async {
    final currentSshService = ref.read(sshServiceProvider);
    if (currentSshService.isConnected) {
      // Navigate to Terminal screen
      if (mounted) {
        await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const TerminalScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                )),
                child: child,
              );
            },
          ),
        );
        
        // When returning from Terminal, ensure play button is hidden
        if (mounted) {
          await LiquidGlassPlayButton.hide();
          debugPrint('✅ Returned to native SSH screen');
        }
      }
    }
  }
  
  void _handleConnectTapped(
    String ip,
    String port,
    String username,
    String password,
    String privateKey,
    String privateKeyPassphrase,
  ) async {
    debugPrint('🔌 Connect button tapped: $username@$ip:$port');
    
    try {
      // Attempt SSH connection
      await ref.read(sshServiceProvider.notifier).connect(
        host: ip,
        port: int.parse(port),
        username: username,
        password: password.isNotEmpty ? password : null,
        privateKey: privateKey.isNotEmpty ? privateKey : null,
        privateKeyPassphrase: privateKeyPassphrase.isNotEmpty ? privateKeyPassphrase : null,
      );
      
      // Save credentials
      await ref.read(credentialStorageServiceProvider).saveCredentials(
        ip: ip,
        port: int.parse(port),
        username: username,
        password: password.isNotEmpty ? password : null,
        privateKey: privateKey.isNotEmpty ? privateKey : null,
        privateKeyPassphrase: privateKeyPassphrase.isNotEmpty ? privateKeyPassphrase : null,
      );
      
      ref.read(connectedIpProvider.notifier).state = ip;
      ref.read(connectedUsernameProvider.notifier).state = username;
      
      // Show success animation then update to connected state
      await LiquidGlassPowerButton.showSuccessAnimation();
      await Future.delayed(const Duration(milliseconds: 800));
      await LiquidGlassPowerButton.updateState(isConnected: true);
      
      // Stop loading on native screen
      await NativeSSHScreen.stopLoading();
      
      // Auto-navigate to Terminal screen
      if (mounted) {
        await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const TerminalScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                )),
                child: child,
              );
            },
          ),
        );
        
        // When returning from Terminal, ensure play button is hidden
        if (mounted) {
          await LiquidGlassPlayButton.hide();
          debugPrint('✅ Returned to native SSH screen after connection');
        }
      }
    } catch (e) {
      debugPrint('❌ SSH Connection Error: $e');
      
      // Stop loading
      await NativeSSHScreen.stopLoading();
      
      // Show error message
      String errorMessage = 'Failed to connect';
      String errorDetails = e.toString().toLowerCase();
      
      if (errorDetails.contains('timeout') || errorDetails.contains('connection timeout')) {
        errorMessage = 'Connection timeout - check server IP and port';
      } else if (errorDetails.contains('connection refused') || errorDetails.contains('unreachable')) {
        errorMessage = 'Server unreachable - check IP address and port';
      } else if (errorDetails.contains('authentication') || errorDetails.contains('auth') || errorDetails.contains('password') || errorDetails.contains('permission denied')) {
        errorMessage = 'Authentication failed - check username and password/key';
      } else if (errorDetails.contains('private key') || errorDetails.contains('key')) {
        errorMessage = 'Private key error - check key format and passphrase';
      } else if (errorDetails.contains('host key') || errorDetails.contains('fingerprint')) {
        errorMessage = 'Host key verification failed';
      } else if (errorDetails.contains('socket') || errorDetails.contains('network')) {
        errorMessage = 'Network error - check your internet connection';
      } else {
        errorMessage = 'Connection failed: ${e.toString()}';
      }
      
      await NativeSSHScreen.showConnectionError(errorMessage);
    }
  }
  
  void _handleLoadCredentials() async {
    debugPrint('📂 Load credentials tapped');
    
    // Load saved credentials
    final credentials = await ref.read(credentialStorageServiceProvider).loadCredentials();
    
    if (credentials != null) {
      await NativeSSHScreen.loadCredentials(
        ip: credentials['ip'] ?? '',
        port: credentials['port']?.toString() ?? '22',
        username: credentials['username'] ?? '',
        password: credentials['password'],
        privateKey: credentials['privateKey'],
        privateKeyPassphrase: credentials['privateKeyPassphrase'],
      );
      
      // Show success toast
      await LiquidGlassToast.show(
        message: 'Recent credentials loaded',
        style: 'success',
        duration: 1.5,
      );
    } else {
      // No credentials found
      await NativeSSHScreen.stopLoading();
      await LiquidGlassToast.show(
        message: 'No recent credentials found',
        style: 'info',
        duration: 1.5,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Empty container - the native SSH screen is rendered natively
    return Container(
      color: const Color(0xFF0a0a0a),
    );
  }
  
  @override
  void dispose() {
    // Don't hide the native screen here - it will be managed by navigation
    super.dispose();
  }
}

