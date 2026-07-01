import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      if (auth.user?.role == 'admin') {
        Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(Icons.newspaper_rounded, size: 64, color: Theme.of(context).colorScheme.primary)
                                .animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                            const SizedBox(height: 16),
                            Text(
                              'Welcome Back',
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ).animate().fade().slideY(begin: 0.2, duration: 400.ms),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to stay updated',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ).animate().fade().slideY(begin: 0.2, duration: 400.ms, delay: 100.ms),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) =>
                                  (value == null || value.isEmpty) ? 'Enter your email' : null,
                            ).animate().fade().slideX(begin: 0.1, duration: 400.ms, delay: 200.ms),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              validator: (value) =>
                                  (value == null || value.length < 6) ? 'Minimum 6 characters' : null,
                            ).animate().fade().slideX(begin: 0.1, duration: 400.ms, delay: 300.ms),
                            if (auth.errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                auth.errorMessage!.replaceAll('Exception: ', ''),
                                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ).animate().fade().slideY(begin: -0.1),
                            ],
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: auth.isLoading ? null : _submit,
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Login'),
                            ).animate().fade().scaleXY(begin: 0.9, duration: 400.ms, delay: 400.ms),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pushReplacementNamed(context, AppRoutes.register),
                              style: TextButton.styleFrom(foregroundColor: Colors.black),
                              child: const Text('Create an account'),
                            ).animate().fade(delay: 500.ms),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
    );
  }
}
