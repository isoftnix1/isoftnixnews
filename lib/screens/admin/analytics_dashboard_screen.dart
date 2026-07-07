import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _userStats = [];

  @override
  void initState() {
    super.initState();
    _fetchGlobalAnalytics();
  }

  Future<void> _fetchGlobalAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _apiService.getGlobalAnalytics();
      setState(() {
        _userStats = stats;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load analytics: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Analytics'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchGlobalAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userStats.isEmpty
              ? _buildEmptyState()
              : _buildLeaderboard(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'No usage data available yet.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userStats.length,
      itemBuilder: (context, index) {
        final stat = _userStats[index];
        final name = stat['name'] ?? 'Unknown User';
        final email = stat['email'] ?? 'No Email';
        // 'total_seconds' comes as a String or int depending on Postgres driver, so parse carefully
        final totalSeconds = int.tryParse(stat['total_seconds']?.toString() ?? '0') ?? 0;
        final isTopThree = index < 3;

        return Card(
          elevation: isTopThree ? 4 : 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isTopThree ? Colors.teal : Colors.grey.shade300,
              foregroundColor: isTopThree ? Colors.white : Colors.black87,
              radius: 24,
              child: isTopThree
                  ? const Icon(Icons.star_rounded, size: 28)
                  : Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text(email),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatTime(totalSeconds),
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
