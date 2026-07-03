import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../utils/validators.dart';
import '../../l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final avatarBg = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3F0FF);
    final cardBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final surfaceBg = isDark ? const Color(0xFF0F0F23) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context, 'profile'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            // ── Avatar card ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 60 : 18),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: avatarBg,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.primaryColor.withAlpha(80),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            (user?.name.isNotEmpty == true)
                                ? user!.name[0].toUpperCase()
                                : 'G',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().scale(
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'Guest',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (user?.role ?? 'user').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.primaryColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ).animate().fadeIn(delay: 150.ms),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // ── Info section ─────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 60 : 18),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _InfoTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Full Name',
                    value: user?.name ?? '—',
                    isFirst: true,
                    onEdit: user == null
                        ? null
                        : () => _showEditDialog(
                              context,
                              title: 'Edit Name',
                              label: 'Full Name',
                              currentValue: user.name,
                              keyboardType: TextInputType.name,
                              onSave: (val) =>
                                  context.read<AuthProvider>().updateProfile(name: val),
                            ),
                  ),
                  _Divider(),
                  _InfoTile(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: user?.email ?? '—',
                    onEdit: user == null
                        ? null
                        : () => _showEditDialog(
                              context,
                              title: 'Edit Email',
                              label: 'Email Address',
                              currentValue: user.email,
                              keyboardType: TextInputType.emailAddress,
                              // Email update goes through name field as workaround;
                              // backend PUT /auth/me currently supports name & phone.
                              // Keep field read-only with a note for now.
                              readOnly: true,
                              readOnlyNote:
                                  'Email cannot be changed for security reasons.',
                              onSave: (_) async => false,
                            ),
                  ),
                  _Divider(),
                  _InfoTile(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: (user?.phone != null && user!.phone!.isNotEmpty)
                        ? '+91 ${user.phone!}'
                        : 'Not set',
                    isLast: true,
                    onEdit: user == null
                        ? null
                        : () => _showEditDialog(
                              context,
                              title: 'Edit Phone',
                              label: 'Phone Number',
                              currentValue: user.phone ?? '',
                              keyboardType: TextInputType.phone,
                              prefixText: '+91 ',
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: Validators.indianPhone,
                              helperText:
                                  '10-digit Indian mobile number starting with 6–9',
                              onSave: (val) => context
                                  .read<AuthProvider>()
                                  .updateProfile(
                                    phone: Validators.normalizeIndianPhone(val),
                                  ),
                            ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),

            const SizedBox(height: 32),

            // ── Logout button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged out successfully')),
                    );
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: Text(
                  AppLocalizations.of(context, 'logout'),
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.redAccent, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context, {
    required String title,
    required String label,
    required String currentValue,
    required TextInputType keyboardType,
    required Future<bool> Function(String) onSave,
    bool readOnly = false,
    String? readOnlyNote,
    String? prefixText,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    String? helperText,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final auth = ctx.watch<AuthProvider>();
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (readOnlyNote != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          readOnlyNote,
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    TextFormField(
                      controller: controller,
                      keyboardType: keyboardType,
                      readOnly: readOnly,
                      maxLength: maxLength,
                      inputFormatters: inputFormatters,
                      decoration: InputDecoration(
                        labelText: label,
                        prefixText: prefixText,
                        helperText: helperText,
                        counterText: maxLength != null ? '' : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: validator ??
                          (val) {
                            if (!readOnly &&
                                (val == null || val.trim().isEmpty)) {
                              return '$label cannot be empty';
                            }
                            return null;
                          },
                    ),
                    if (auth.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          auth.errorMessage!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                if (!readOnly)
                  FilledButton(
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            final success =
                                await onSave(controller.text.trim());
                            if (success && ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$label updated!'),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              );
                            }
                          },
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Reusable info tile ───────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onEdit;
  final bool isFirst;
  final bool isLast;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 8 : 0,
        bottom: isLast ? 8 : 0,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.primaryColor.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.primaryColor, size: 20),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withAlpha(140),
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        trailing: onEdit != null
            ? IconButton(
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: theme.primaryColor,
                ),
                tooltip: 'Edit $label',
                style: IconButton.styleFrom(
                  backgroundColor: theme.primaryColor.withAlpha(18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 72,
      endIndent: 20,
      color: Theme.of(context).dividerColor.withAlpha(80),
    );
  }
}
