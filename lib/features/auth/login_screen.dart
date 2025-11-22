import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/auth_token.dart';
import '../../data/services/api_client.dart';
import '../../data/services/auth_service.dart';
import '../../router_simple.dart' show setAuthToken;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ [LOGIN] Form validation failed');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    debugPrint('🔐 [LOGIN] Starting login for: $email');
    
    try {
      setState(() {
        _isLoading = true;
      });

      debugPrint('📡 [LOGIN] Calling authService.login() directly...');
      // Use services DIRECTLY - no Riverpod providers at all
      ApiClient? apiClient;
      AuthService? authService;
      
      try {
        debugPrint('🔧 [LOGIN] Creating ApiClient...');
        apiClient = ApiClient();
        debugPrint('✅ [LOGIN] ApiClient created');
        
        debugPrint('🔧 [LOGIN] Creating AuthService...');
        authService = AuthService(apiClient);
        debugPrint('✅ [LOGIN] AuthService created');
        
        debugPrint('🔧 [LOGIN] Calling login method...');
        final token = await authService.login(email, password).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw Exception('Login request timed out. Please check your internet connection and try again.');
          },
        );
        debugPrint('✅ [LOGIN] Login successful! Token: ${token.accessToken.substring(0, 20)}...');

        if (!mounted) return;
        
        // Update the simple auth notifier - this triggers router refresh
        debugPrint('🔧 [LOGIN] Updating auth token...');
        setAuthToken(token);
        
        // Wait a brief moment for state to propagate
        await Future.delayed(const Duration(milliseconds: 50));
        
        if (!mounted) return;
        
        // Navigate to home
        debugPrint('🚀 [LOGIN] Navigating to /home');
        context.go('/home');
      } on Exception catch (e, stack) {
        debugPrint('❌ [LOGIN] Login error: $e');
        debugPrint('   - Error type: ${e.runtimeType}');
        debugPrint('   - Error toString: ${e.toString()}');
        debugPrint('   - Stack: $stack');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e, stack) {
        debugPrint('💥 [LOGIN] Unexpected error type: ${e.runtimeType}');
        debugPrint('   - Error: $e');
        debugPrint('   - Stack: $stack');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unexpected error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e, stack) {
      debugPrint('💥 [LOGIN] Exception caught: $e');
      debugPrint('   - Stack: $stack');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // DON'T watch authStateProvider - it causes minified:WR error
    // Use local _isLoading state instead
    final isLoading = _isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ProBilling',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ) ?? const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isLoading ? null : _handleLogin,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      context.push('/register');
                    },
                    child: const Text('Don\'t have an account? Register'),
                  ),
                  // Debug section removed - was causing minified:WR error by watching authStateProvider
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

