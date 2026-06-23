import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final isAdmin = user?.role == 'admin';
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: Column(
        children: [
          // Drawer Header with nice gradient or color
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              bottom: 24,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: theme.primaryColor,
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor,
                  theme.primaryColor.withAlpha(200),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Text(
                    (user?.name ?? 'G')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Guest User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'Sign in to access more features',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                _DrawerItem(
                  icon: Icons.home_rounded,
                  title: 'Home',
                  onTap: () {
                    Navigator.pop(context);
                    if (ModalRoute.of(context)?.settings.name != AppRoutes.home) {
                      Navigator.pushReplacementNamed(context, AppRoutes.home);
                    }
                  },
                ),
                _DrawerItem(
                  icon: Icons.person_rounded,
                  title: 'Profile',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.profile);
                  },
                ),
                if (isAdmin)
                  _DrawerItem(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Admin Dashboard',
                    onTap: () {
                      Navigator.pop(context);
                      if (ModalRoute.of(context)?.settings.name != AppRoutes.adminDashboard) {
                        Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
                      }
                    },
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
                  child: Divider(height: 1),
                ),
                if (user != null)
                  _DrawerItem(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    textColor: Colors.redAccent,
                    iconColor: Colors.redAccent,
                    onTap: () {
                      authProvider.logout();
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    },
                  )
                else
                  _DrawerItem(
                    icon: Icons.login_rounded,
                    title: 'Login',
                    onTap: () {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    },
                  ),
              ],
            ),
          ),
          // App Version Footer
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SafeArea(
              top: false,
              child: Text(
                'ISoftNix News v1.0.0',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withAlpha(100),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? (isDark ? Colors.white70 : Colors.black87),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            color: textColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
        splashColor: theme.primaryColor.withAlpha(25),
        hoverColor: theme.primaryColor.withAlpha(10),
      ),
    );
  }
}
