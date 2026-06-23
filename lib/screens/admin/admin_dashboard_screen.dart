import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../widgets/app_drawer.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          children: [
            _DashboardCard(
              icon: Icons.newspaper,
              title: 'Manage News',
              onTap: () => Navigator.pushNamed(context, AppRoutes.adminNewsList),
            ),
            _DashboardCard(
              icon: Icons.add_circle,
              title: 'Add News',
              onTap: () => Navigator.pushNamed(context, AppRoutes.addNews),
            ),
            _DashboardCard(
              icon: Icons.category,
              title: 'Manage Categories',
              onTap: () => Navigator.pushNamed(context, AppRoutes.manageCategories),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blueGrey),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
