import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import '../../data/models/auth_token.dart';
import '../../router.dart' show updateGlobalAuthNotifier;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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

      debugPrint('📡 [LOGIN] Calling authNotifier.login()...');
      final authNotifier = ref.read(authStateProvider.notifier);
      try {
        final token = await authNotifier.login(email, password);
        debugPrint('✅ [LOGIN] Login successful! Token: ${token.accessToken.substring(0, 20)}...');

        if (!mounted) return;
        
        // Update the global auth notifier FIRST - this triggers router refresh
        debugPrint('🔧 [LOGIN] Updating global auth notifier with token...');
        updateGlobalAuthNotifier(token);
        
        // Wait a brief moment for state to propagate
        await Future.delayed(const Duration(milliseconds: 50));
        
        if (!mounted) return;
        
        // Navigate to home - router redirect should handle it, but force it
        debugPrint('🚀 [LOGIN] Navigating to /home');
        context.go('/home');
        
        // Ensure navigation happens even if router redirect is slow
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          
          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted) return;
          
          final currentPath = GoRouterState.of(context).matchedLocation;
          debugPrint('🔍 [LOGIN] Post-frame check - Current path: $currentPath');
          
          if (currentPath == '/login' || currentPath.startsWith('/login')) {
            debugPrint('🚀 [LOGIN] Still on login page, forcing navigation to /home');
            context.go('/home');
          }
        });
      } on Exception catch (e) {
        debugPrint('❌ [LOGIN] Login error: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
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

