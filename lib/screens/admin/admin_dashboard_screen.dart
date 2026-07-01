import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_drawer.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = context.watch<AuthProvider>().user?.name ?? 'Admin';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      drawer: const AppDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Three breakpoints:
          //  < 600   → phone: 2 cols, tall cards
          //  600–799 → tablet portrait: 2 cols, medium cards
          //  ≥ 800   → tablet landscape: 3 cols, wide short cards
          final width = constraints.maxWidth;
          final isPhone = width < 600;
          final isTabletPortrait = width >= 600 && width < 800;
          final isTabletLandscape = width >= 800;

          final crossAxisCount = isTabletLandscape ? 3 : 2;
          final childAspectRatio = isPhone
              ? 0.9
              : isTabletPortrait
                  ? 1.0   // taller cards in portrait so content fits
                  : 1.5;  // landscape — wider, shorter
          final maxWidth = isTabletLandscape ? 900.0 : isTabletPortrait ? 700.0 : double.infinity;
          final isTablet = !isPhone;

          final actions = [
            _DashboardAction(
              title: 'Manage\nNews',
              icon: Icons.newspaper_rounded,
              color: Colors.blue,
              route: AppRoutes.adminNewsList,
              delay: 400,
            ),
            _DashboardAction(
              title: 'Add New\nArticle',
              icon: Icons.add_circle_rounded,
              color: Colors.green,
              route: AppRoutes.addNews,
              delay: 500,
            ),
            _DashboardAction(
              title: 'Manage\nCategories',
              icon: Icons.category_rounded,
              color: Colors.orange,
              route: AppRoutes.manageCategories,
              delay: 600,
            ),
          ];

          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 32 : 24,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        'Welcome back,',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
                      const SizedBox(height: 4),
                      Text(
                        userName,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
                      const SizedBox(height: 8),
                      Text(
                        'Here is what is happening with your news portal today.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                      const SizedBox(height: 32),
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 16),

                      // Responsive Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemCount: actions.length,
                        itemBuilder: (context, index) {
                          final action = actions[index];
                          return _buildDashboardCard(
                            context,
                            title: action.title,
                            icon: action.icon,
                            color: action.color,
                            isTablet: isTablet,
                            onTap: () =>
                                Navigator.pushNamed(context, action.route),
                          )
                              .animate()
                              .scale(
                                delay: Duration(milliseconds: action.delay),
                                duration: 400.ms,
                                curve: Curves.easeOutBack,
                              );
                        },
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isTablet = false,
  }) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: isDark ? 0.2 : 0.1),
              color.withValues(alpha: isDark ? 0.05 : 0.02),
            ],
          ),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.3 : 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 12 : 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: isTablet ? 30 : 28, color: color),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple data class for dashboard action items.
class _DashboardAction {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  final int delay;

  const _DashboardAction({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
    required this.delay,
  });
}
