import 'dart:ui' as ui;
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
        appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
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
              title: 'Manage\nDrafts',
              icon: Icons.edit_document,
              color: Colors.amber,
              route: AppRoutes.adminDraftsList,
              delay: 550,
            ),
            _DashboardAction(
              title: 'Manage\nCategories',
              icon: Icons.category_rounded,
              color: Colors.orange,
              route: AppRoutes.manageCategories,
              delay: 600,
            ),
            _DashboardAction(
              title: 'Device\nManagement',
              icon: Icons.devices_rounded,
              color: Colors.purple,
              route: AppRoutes.deviceManagement,
              delay: 700,
            ),
            _DashboardAction(
              title: 'Hardware\nLock',
              icon: Icons.lock_person_rounded,
              color: Colors.redAccent,
              route: AppRoutes.hardwareLock,
              delay: 800,
            ),
            _DashboardAction(
              title: 'User\nAnalytics',
              icon: Icons.analytics_rounded,
              color: Colors.teal,
              route: AppRoutes.adminAnalytics,
              delay: 900,
            ),
            _DashboardAction(
              title: 'Manage\nAds',
              icon: Icons.campaign_rounded,
              color: Colors.indigo,
              route: AppRoutes.adminAds,
              delay: 1000,
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
                                  .withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
                      const SizedBox(height: 4),
                      Text(
                        userName,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            ),
                      ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
                      const SizedBox(height: 8),
                      Text(
                        'Here is what is happening with your news portal today.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.8),
                            ),
                      ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                      const SizedBox(height: 32),
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.surface.withValues(alpha: isDark ? 0.5 : 0.7),
                      Theme.of(context).colorScheme.surface.withValues(alpha: isDark ? 0.3 : 0.5),
                    ],
                  ),
                  border: Border.all(
                    color: color.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 12 : 10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(alpha: 0.3),
                          width: 1,
                        )
                      ),
                      child: Icon(icon, size: isTablet ? 30 : 28, color: color),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: color,
                          ),
                        ),
                      ],
                    ),
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
