import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class HardwareLockScreen extends StatefulWidget {
  const HardwareLockScreen({super.key});

  @override
  State<HardwareLockScreen> createState() => _HardwareLockScreenState();
}

class _HardwareLockScreenState extends State<HardwareLockScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _slots = [];
  List<Map<String, dynamic>> _pendingDevices = [];

  @override
  void initState() {
    super.initState();
    _fetchSlots();
    _fetchPendingDevices();
  }

  Future<void> _fetchSlots() async {
    setState(() => _isLoading = true);
    try {
      final slots = await _apiService.getAdminHardwareSlots();
      setState(() {
        _slots = slots;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load hardware slots: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPendingDevices() async {
    try {
      final pending = await _apiService.getPendingDevices();
      setState(() {
        _pendingDevices = pending;
      });
    } catch (e) {
      // It's okay if this fails quietly or logs, since it's a secondary feature
      debugPrint('Failed to fetch pending devices: $e');
    }
  }



  Future<void> _authorizePendingDeviceFlow(String attemptId) async {
    final passwordController = TextEditingController();
    int selectedSlot = 2; // Default to 2
    bool requestLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Authorize Device'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Which slot do you want to assign this device to?'),
                  DropdownButton<int>(
                    value: selectedSlot,
                    items: [1, 2, 3, 4, 5].map((slot) {
                      return DropdownMenuItem(
                        value: slot,
                        child: Text('Slot $slot'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedSlot = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Admin Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (requestLoading) const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: CircularProgressIndicator(),
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: requestLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: requestLoading
                      ? null
                      : () async {
                          if (passwordController.text.isEmpty) return;
                          setDialogState(() => requestLoading = true);
                          try {
                            await _apiService.authorizePendingDevice(
                              attemptId: attemptId,
                              slotNumber: selectedSlot,
                              password: passwordController.text,
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Device successfully authorized.')),
                            );
                            _fetchSlots();
                            _fetchPendingDevices();
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                            );
                            setDialogState(() => requestLoading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Authorize', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware Lock Management'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Hardware Slots',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ..._slots.map((slotWrapper) {
                    final slotNumber = slotWrapper['slot'];
                    final slotData = slotWrapper['data'];
                    final bool isEmpty = slotData == null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Slot $slotNumber',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                if (isEmpty)
                                  const Chip(label: Text('Empty'), backgroundColor: Colors.orange)
                                else
                                  const Chip(label: Text('Active'), backgroundColor: Colors.green)
                              ],
                            ),
                            const Divider(),
                            if (isEmpty)
                              const Text('No hardware registered in this slot.')
                            else ...[
                              Text('Device Name: ${slotData['deviceName'] ?? 'Unknown'}'),
                              Text('Platform: ${slotData['platform'] ?? 'Unknown'}'),
                              Text('OS Version: ${slotData['osVersion'] ?? 'Unknown'}'),
                              Text('App Version: ${slotData['appVersion'] ?? 'Unknown'}'),
                              Text('Last Updated: ${slotData['lastUpdatedAt'] != null ? DateTime.parse(slotData['lastUpdatedAt']).toLocal().toString().split('.')[0] : 'Unknown'}'),
                            ],
                            // Note: Old "Replace Device" button removed since we now use the Pending queue for new devices
                          ],
                        ),
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 32),
                  const Text(
                    'Recent Blocked Login Attempts',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const Text(
                    'If you tried to log in on a new device and were blocked, it will appear here. You can authorize it to an empty slot.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  if (_pendingDevices.isEmpty)
                    const Text('No recent blocked attempts found.')
                  else
                    ..._pendingDevices.map((pending) {
                      final timeStr = pending['created_at'] != null 
                          ? DateTime.parse(pending['created_at']).toLocal().toString().split('.')[0] 
                          : 'Unknown';
                          
                      final deviceInfo = pending['device_info'];
                      final hasDeviceInfo = deviceInfo != null;
                      final titleStr = hasDeviceInfo 
                          ? 'Device: ${deviceInfo['deviceName'] ?? 'Unknown'}' 
                          : 'IP: ${pending['ip_address']}';
                          
                      final subtitleStr = hasDeviceInfo
                          ? 'Platform: ${deviceInfo['platform'] ?? 'Unknown'} (${deviceInfo['osVersion'] ?? '?'})\nTime: $timeStr'
                          : 'Time: $timeStr\nUser-Agent: ${pending['user_agent']}';

                      return Card(
                        color: Colors.red.shade50,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          title: Text(titleStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(subtitleStr),
                          isThreeLine: true,
                          trailing: ElevatedButton(
                            onPressed: () => _authorizePendingDeviceFlow(pending['id'].toString()),
                            child: const Text('Authorize'),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
