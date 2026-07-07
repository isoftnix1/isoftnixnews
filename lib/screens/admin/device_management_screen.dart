import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final ApiService _api = ApiService();
  
  bool _isLoading = true;
  String _statusFilter = 'All';
  String _platformFilter = 'All';
  
  List<Map<String, dynamic>> _devices = [];
  Map<String, dynamic>? _analytics;

  final List<String> _statusOptions = ['All', 'Active', 'Inactive', 'Possible Uninstalled'];
  final List<String> _platformOptions = ['All', 'android', 'ios'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        _api.getAdminDeviceList(status: _statusFilter, platform: _platformFilter),
        _api.getAdminDeviceAnalytics(),
      ]);
      if (mounted) {
        setState(() {
          _devices = futures[0] as List<Map<String, dynamic>>;
          _analytics = futures[1] as Map<String, dynamic>;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading devices: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAnalyticsCards(isDark),
              const SizedBox(height: 24),
              _buildFilters(isDark),
              const SizedBox(height: 16),
              _buildDeviceList(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCards(bool isDark) {
    if (_isLoading && _analytics == null) {
      return Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(height: 120, color: Colors.white),
      );
    }

    final data = _analytics ?? {};
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatCard(title: 'Active', value: '${data['active_users'] ?? 0}', color: Colors.green, isDark: isDark),
          _StatCard(title: 'Inactive', value: '${data['inactive_users'] ?? 0}', color: Colors.orange, isDark: isDark),
          _StatCard(title: 'Uninstalled', value: '${data['possible_uninstalled'] ?? 0}', color: Colors.red, isDark: isDark),
          _StatCard(title: 'Android', value: '${data['android_users'] ?? 0}', color: Colors.blue, isDark: isDark),
          _StatCard(title: 'iOS', value: '${data['ios_users'] ?? 0}', color: Colors.purple, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _statusFilter,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _statusOptions.map((s) => DropdownMenuItem(
              value: s, 
              child: Text(s, overflow: TextOverflow.ellipsis)
            )).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _statusFilter = val);
                _loadData();
              }
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _platformFilter,
            decoration: const InputDecoration(
              labelText: 'Platform',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _platformOptions.map((s) => DropdownMenuItem(
              value: s, 
              child: Text(s, overflow: TextOverflow.ellipsis)
            )).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _platformFilter = val);
                _loadData();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceList(bool isDark) {
    if (_isLoading && _devices.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }

    if (_devices.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No devices found.')));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _devices.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final device = _devices[index];
        final isAndroid = device['platform'] == 'android';
        
        Color statusColor = Colors.green;
        IconData statusIcon = Icons.check_circle;
        
        if (device['app_status'] == 'inactive') {
          statusColor = Colors.orange;
          statusIcon = Icons.access_time_filled;
        } else if (device['app_status'] == 'possible_uninstalled') {
          statusColor = Colors.red;
          statusIcon = Icons.warning_rounded;
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            child: Icon(
              isAndroid ? Icons.android : Icons.apple,
              color: isAndroid ? Colors.green : (isDark ? Colors.white : Colors.black),
            ),
          ),
          title: Text('${device['user_name'] ?? 'Unknown'} • ${device['device_name'] ?? 'Unknown'}'),
          subtitle: Text('Last seen: ${_formatDate(device['last_seen_at'])}'),
          trailing: Icon(statusIcon, color: statusColor),
          onTap: () => _showDeviceDetails(context, device, isDark),
        );
      },
    );
  }

  void _showDeviceDetails(BuildContext context, Map<String, dynamic> device, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 32),
            Expanded(
              child: ListView(
                children: [
                  _DetailRow('User', device['user_name'] ?? 'N/A'),
                  _DetailRow('Email', device['user_email'] ?? 'N/A'),
                  _DetailRow('Phone', device['user_phone'] ?? 'N/A'),
                  const Divider(height: 32),
                  _DetailRow('Platform', (device['platform'] ?? 'N/A').toString().toUpperCase()),
                  _DetailRow('Manufacturer', device['manufacturer'] ?? 'N/A'),
                  _DetailRow('Model', device['model'] ?? 'N/A'),
                  _DetailRow('OS Version', device['os_version'] ?? 'N/A'),
                  _DetailRow('App Version', device['app_version'] ?? 'N/A'),
                  const Divider(height: 32),
                  _DetailRow('Status', device['app_status'] ?? 'N/A'),
                  _DetailRow('Notification Status', device['notification_status'] ?? 'N/A'),
                  _DetailRow('Registered', _formatDate(device['created_at'])),
                  _DetailRow('Last Seen', _formatDate(device['last_seen_at'])),
                  _DetailRow('Last Notified', _formatDate(device['last_notification_sent_at'])),
                  _DetailRow('Uninstall Detected', _formatDate(device['uninstall_detected_at'])),
                  const Divider(height: 32),
                  _DetailRow('FCM Token', _maskToken(device['fcm_token'] ?? '')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Never';
    try {
      final d = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM d, yyyy • h:mm a').format(d);
    } catch (_) {
      return 'Invalid Date';
    }
  }

  String _maskToken(String token) {
    if (token.length <= 20) return '***';
    return '${token.substring(0, 10)}...${token.substring(token.length - 10)}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
