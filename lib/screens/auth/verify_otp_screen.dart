import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../utils/validators.dart';

class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final resetToken = await auth.verifyResetOtp(
      email: widget.email,
      otp: _otpController.text.trim(),
    );

    if (!mounted) return;

    if (resetToken != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.resetPassword,
        arguments: resetToken,
      );
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }

  Future<void> _resendCode() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.forgotPassword(email: widget.email);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'If an account exists with that email, a new verification code has been sent.'
              : auth.errorMessage ?? 'Unable to resend code. Please try again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
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
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 16),
                    Text(
                      'Enter verification code',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ).animate().fade().slideY(begin: 0.2, duration: 400.ms),
                    const SizedBox(height: 8),
                    Text(
                      'We sent a 6-digit code to ${widget.email}. It expires in 10 minutes.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ).animate().fade().slideY(begin: 0.2, duration: 400.ms, delay: 80.ms),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '6-digit OTP',
                        prefixIcon: Icon(Icons.pin_outlined),
                        counterText: '',
                      ),
                      validator: Validators.otp,
                      onFieldSubmitted: (_) => _submit(),
                    ).animate().fade().slideX(begin: 0.1, duration: 400.ms, delay: 200.ms),
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
                          : const Text('Verify OTP'),
                    ).animate().fade().scaleXY(begin: 0.9, duration: 400.ms, delay: 300.ms),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: auth.isLoading ? null : _resendCode,
                      child: const Text('Resend code'),
                    ).animate().fade(delay: 400.ms),
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
