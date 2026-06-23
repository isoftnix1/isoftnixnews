import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
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
                  const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 64,
                    color: Colors.white,
                  ).animate().scale(
                        duration: 500.ms,
                        curve: Curves.easeOutBack,
                      ),

                  const SizedBox(height: 16),

                  Text(
                    'Create Account',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ).animate().fade().slideY(
                        begin: 0.2,
                        duration: 400.ms,
                      ),

                  const SizedBox(height: 8),

                  Text(
                    'Join ISoftNix News today',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ).animate().fade().slideY(
                        begin: 0.2,
                        duration: 400.ms,
                        delay: 100.ms,
                      ),

                  const SizedBox(height: 32),

                  TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Fill this field';
                          }
                          return null;
                      },
                    ).animate().fade().slideX(
                        begin: 0.1,
                        duration: 400.ms,
                        delay: 150.ms,
                      ),

                  const SizedBox(height: 16),

                  TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Fill this field';
                          }

                          if (!RegExp(
                            r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$',
                          ).hasMatch(value.trim())) {
                            return 'Enter valid email';
                          }

                          return null;
                      },
                    ).animate().fade().slideX(
                        begin: 0.1,
                        duration: 400.ms,
                        delay: 250.ms,
                      ),

                  const SizedBox(height: 16),

                  TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Fill this field';
                        }

                        if (!RegExp(r'^[0-9]{10}$').hasMatch(value.trim())) {
                          return 'Enter valid 10-digit phone number';
                        }

                        return null;
                      },
                    ).animate().fade().slideX(
                                            begin: 0.1,
                                            duration: 400.ms,
                                            delay: 250.ms,
                                          ),

                  const SizedBox(height: 16),

                  TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Fill this field';
                          }

                          if (value.length < 6) {
                            return 'Minimum 6 characters';
                          }

                          return null;
                        },
                      ).animate().fade().slideX(
                            begin: 0.1,
                            duration: 400.ms,
                            delay: 300.ms,
                          ),

                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          auth.errorMessage!.replaceAll('Exception: ', ''),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: auth.isLoading ? null : _submit,
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Register'),
                  ).animate().fade().scaleXY(
                        begin: 0.9,
                        duration: 400.ms,
                        delay: 400.ms,
                      ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.login,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                    ),
                    child: const Text(
                      'Already have an account? Login',
                    ),
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
