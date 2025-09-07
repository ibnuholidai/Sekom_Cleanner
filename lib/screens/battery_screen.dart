import 'package:flutter/material.dart';
import '../models/system_status.dart';
import '../services/system_service.dart';

class BatteryScreen extends StatefulWidget {
  const BatteryScreen({super.key});

  @override
  State<BatteryScreen> createState() => _BatteryScreenState();
}

class _BatteryScreenState extends State<BatteryScreen> {
  BatteryStatus _batteryStatus = BatteryStatus();
  bool _isLoading = false;
  String _statusMessage = "Klik 'Periksa Baterai' untuk melihat informasi baterai";

  @override
  void initState() {
    super.initState();
    _checkBatteryStatus();
  }

  Future<void> _checkBatteryStatus() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _statusMessage = "Memeriksa status baterai...";
    });

    try {
      BatteryStatus status = await SystemService.getBatteryStatus();
      if (!mounted) return;
      setState(() {
        _batteryStatus = status;
        _statusMessage = _batteryStatus.isPresent
            ? "Informasi baterai berhasil dimuat"
            : "Tidak ada baterai yang terdeteksi (mungkin PC desktop)";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = "Error: ${e.toString()}";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setPowerPlan(String planType) async {
    if (!mounted) return;
    setState(() {
      _statusMessage = "Mengubah power plan ke $planType...";
    });

    bool success = await SystemService.setPowerPlan(planType);
    if (!mounted) return;

    if (success) {
      setState(() {
        _statusMessage = "Power plan berhasil diubah ke $planType";
      });
      // Refresh battery status to get updated power plan
      if (mounted) {
        await _checkBatteryStatus();
      }
    } else {
      setState(() {
        _statusMessage = "Gagal mengubah power plan";
      });
    }
  }

  Future<void> _generateBatteryReport() async {
    if (!mounted) return;
    setState(() {
      _statusMessage = "Membuat laporan baterai...";
    });

    bool success = await SystemService.generateBatteryReport();
    if (!mounted) return;

    if (success) {
      setState(() {
        _statusMessage = "Laporan baterai berhasil dibuat di Desktop (battery-report.html)";
      });
      if (mounted) {
        _showInfoDialog('Laporan Baterai', 
            'Laporan baterai telah dibuat dan disimpan di Desktop dengan nama "battery-report.html".\n\n'
            'Buka file tersebut dengan browser untuk melihat detail lengkap tentang riwayat baterai Anda.');
      }
    } else {
      setState(() {
        _statusMessage = "Gagal membuat laporan baterai";
      });
    }
  }

  void _showInfoDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBatteryCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_charging_full, size: 24, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Status Baterai',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (!_batteryStatus.isPresent)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.desktop_windows, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tidak ada baterai terdeteksi. Ini mungkin PC desktop atau laptop tanpa baterai.',
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Battery Level
              Row(
                children: [
                  Text(_batteryStatus.batteryIcon, style: TextStyle(fontSize: 24)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Level Baterai: ${_batteryStatus.chargeLevel}%'),
                        SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: _batteryStatus.chargeLevel / 100,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _batteryStatus.chargeLevel > 20 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              // Charging Status
              Row(
                children: [
                  Text(_batteryStatus.chargingIcon, style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text('Status: ${_batteryStatus.chargingState}'),
                ],
              ),
              SizedBox(height: 8),
              
              // Estimated Runtime
              Row(
                children: [
                  Icon(Icons.access_time, size: 20),
                  SizedBox(width: 8),
                  Text('Estimasi Waktu: ${_batteryStatus.estimatedRuntime}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryHealthCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, size: 24, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Kesehatan Baterai',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_batteryStatus.isPresent) ...[
              Row(
                children: [
                  Text(_batteryStatus.healthStatusIcon, style: TextStyle(fontSize: 24)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: ${_batteryStatus.healthStatus}'),
                        Text('Kesehatan: ${_batteryStatus.batteryHealth.toStringAsFixed(1)}%'),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kapasitas Desain:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('${_batteryStatus.designCapacity} mWh'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kapasitas Penuh:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('${_batteryStatus.fullChargeCapacity} mWh'),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tipe Baterai:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(_batteryStatus.batteryType),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Manufaktur:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(_batteryStatus.manufacturer),
                      ],
                    ),
                  ),
                ],
              ),
            ] else
              Text('Informasi kesehatan baterai tidak tersedia'),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerPlanCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.power_settings_new, size: 24, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Pengaturan Daya',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            Text('Power Plan Aktif: ${_batteryStatus.powerPlan}'),
            SizedBox(height: 16),
            
            Text('Ubah Power Plan:', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: 8),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _setPowerPlan('Power Saver'),
                  icon: Icon(Icons.battery_saver, size: 16),
                  label: Text('Power Saver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _setPowerPlan('Balanced'),
                  icon: Icon(Icons.settings, size: 16),
                  label: Text('Balanced'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _setPowerPlan('High Performance'),
                  icon: Icon(Icons.speed, size: 16),
                  label: Text('High Performance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    List<String> recommendations = [];
    
    if (_batteryStatus.isPresent) {
      if (_batteryStatus.batteryHealth < 80) {
        recommendations.add('🔋 Kesehatan baterai menurun, pertimbangkan untuk mengganti baterai');
      }
      if (_batteryStatus.chargeLevel < 20) {
        recommendations.add('⚡ Baterai hampir habis, segera charge');
      }
      if (_batteryStatus.powerPlan == 'High Performance' && !_batteryStatus.isCharging) {
        recommendations.add('💡 Gunakan Power Saver untuk menghemat baterai');
      }
      if (_batteryStatus.batteryHealth >= 80) {
        recommendations.add('✅ Kesehatan baterai masih baik');
      }
    } else {
      recommendations.add('🖥️ PC Desktop terdeteksi - tidak memerlukan manajemen baterai');
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, size: 24, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Rekomendasi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            if (recommendations.isEmpty)
              Text('Tidak ada rekomendasi khusus saat ini')
            else
              ...recommendations.map((rec) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(rec),
              )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Action buttons
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _checkBatteryStatus,
                icon: Icon(Icons.refresh),
                label: Text('🔍 Periksa Baterai'),
              ),
              ElevatedButton.icon(
                onPressed: _generateBatteryReport,
                icon: Icon(Icons.description),
                label: Text('📊 Buat Laporan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          
          // Progress indicator
          if (_isLoading)
            Column(
              children: [
                LinearProgressIndicator(),
                SizedBox(height: 8),
              ],
            ),
          
          // Battery cards
          _buildBatteryCard(),
          SizedBox(height: 16),
          
          _buildBatteryHealthCard(),
          SizedBox(height: 16),
          
          _buildPowerPlanCard(),
          SizedBox(height: 16),
          
          _buildRecommendationsCard(),
          SizedBox(height: 24),
          
          // Status message
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
