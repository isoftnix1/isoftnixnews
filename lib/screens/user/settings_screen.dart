import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../routes/app_routes.dart';
import '../../constants/legal_docs.dart';
import '../user/policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _clearCache(BuildContext context) async {
    try {
      await DefaultCacheManager().emptyCache();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App cache cleared successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to clear cache. Please try again.')),
        );
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone and all your saved preferences will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(child: CircularProgressIndicator()),
              );

              final success = await auth.deleteAccount();
              
              if (!context.mounted) return;
              Navigator.pop(context); // Remove loading indicator

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account permanently deleted')),
                );
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(auth.errorMessage ?? 'Failed to delete account')),
                );
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _openPolicy(BuildContext context, String title, String content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PolicyScreen(title: title, mdContent: content),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final langProvider = context.watch<LanguageProvider>();
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context, 'settings'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        children: [
          // ─── ACCOUNT SECTION ──────────────────────────────────────────
          if (user != null) ...[
            _SectionHeader(title: 'Account'),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(user.email),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final email = user.email;
                    final auth = context.read<AuthProvider>();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sending reset code to your email...')),
                    );
                    
                    final success = await auth.forgotPassword(email: email);
                    
                    if (!context.mounted) return;
                    
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('A verification code has been sent to your email.')),
                      );
                      Navigator.pushNamed(
                        context,
                        AppRoutes.verifyOtp,
                        arguments: email,
                      );
                    } else if (auth.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(auth.errorMessage!)),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // ─── PREFERENCES SECTION ──────────────────────────────────────
          _SectionHeader(title: 'Preferences'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Theme'),
                trailing: DropdownButton<ThemeMode>(
                  value: themeProvider.themeMode,
                  underline: const SizedBox(),
                  onChanged: (ThemeMode? newValue) {
                    if (newValue != null) {
                      themeProvider.setThemeMode(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('System Default')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Light Mode')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark Mode')),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: const Text('Language'),
                trailing: DropdownButton<String>(
                  value: langProvider.currentLanguage,
                  underline: const SizedBox(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      langProvider.changeLanguage(context, newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                    DropdownMenuItem(value: 'mr', child: Text('Marathi')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── PERMISSIONS ──────────────────────────────────────────────
          _SectionHeader(title: 'Permissions'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.security_rounded),
                title: const Text('App Permissions'),
                subtitle: const Text('Manage location, camera, and microphone access'),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () {
                  openAppSettings();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── DATA & STORAGE ───────────────────────────────────────────
          _SectionHeader(title: 'Data & Storage'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.cleaning_services_rounded),
                title: const Text('Clear Media Cache'),
                subtitle: const Text('Frees up local storage space'),
                trailing: FilledButton.tonal(
                  onPressed: () => _clearCache(context),
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── ABOUT & LEGAL ────────────────────────────────────────────
          _SectionHeader(title: 'About & Legal'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openPolicy(
                  context,
                  'Privacy Policy',
                  LegalDocs.privacyPolicy,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openPolicy(
                  context,
                  'Terms of Service',
                  LegalDocs.termsAndConditions,
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('App Version'),
                trailing: Text('v1.0.0', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ─── DANGER ZONE ──────────────────────────────────────────────
          if (user != null) ...[
            FilledButton.icon(
              icon: const Icon(Icons.logout_rounded),
              label: Text(AppLocalizations.of(context, 'logout')),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                foregroundColor: theme.colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () async {
                await authProvider.logout();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logged out successfully')),
                  );
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                }
              },
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('Delete Account'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => _showDeleteAccountDialog(context, authProvider),
            ),
            const SizedBox(height: 48),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50),
        ),
      ),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: children,
      ),
    );
  }
}
