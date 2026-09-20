import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_database/firebase_database.dart'; // প্রজেক্টের রিকোয়ারমেন্ট অনুযায়ী ফায়ারবেস সিঙ্ক

class TrainStatusPage extends ConsumerStatefulWidget {
  final String trainName;

  const TrainStatusPage({super.key, required this.trainName});

  @override
  ConsumerState<TrainStatusPage> createState() => _TrainStatusPageState();
}

class _TrainStatusPageState extends ConsumerState<TrainStatusPage> {
  bool _isServiceActive = true; // ট্রেন রানিং আছে নাকি অফ তা কন্ট্রোল করার জন্য
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTrainRealtimeStatus();
  }

  // ফায়ারবেস বা সার্ভার থেকে ট্রেনের রিয়েল-টাইম স্ট্যাটাস ফেচ করার লজিক
  void _fetchTrainRealtimeStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ref = FirebaseDatabase.instance.ref('train_statuses/${widget.trainName}');
      final snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _isServiceActive = data['is_service_active'] ?? true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isServiceActive = true; // ডিফল্ট রানিং স্ট্যাটাস
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2027),
        elevation: 0,
        title: Text('GLOBAL AI TRAIN TRACKER', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 14)),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    // ট্রেন হেডার কার্ড
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade900,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.tealAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.train, color: Colors.tealAccent, size: 36),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.trainName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  _isServiceActive ? 'Status: Running / On Time' : 'Status: No Service / Off',
                                  style: TextStyle(
                                    color: _isServiceActive ? Colors.greenAccent : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // টগল বাটন (টেস্টিংয়ের জন্য রানিং বা অফ দেখার সুবিধা)
                          IconButton(
                            icon: Icon(_isServiceActive ? Icons.power_settings_new : Icons.lock_outline, color: Colors.amberAccent),
                            onPressed: () {
                              setState(() {
                                _isServiceActive = !_isServiceActive;
                              });
                            },
                            tooltip: 'Toggle Status',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // কন্ডিশনাল রেন্ডারিং: ট্রেন রানিং থাকলে একরকম, অফ থাকলে অন্যরকম UI দেখাবে
                    _isServiceActive ? _buildRunningStatusUI() : _buildNoServiceUI(),
                  ],
                ),
              ),
      ),
    );
  }

  // ১. ট্রেন রানিং বা অন টাইম থাকলে যে ইউআই দেখাবে
  Widget _buildRunningStatusUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.greenAccent, size: 22),
                  SizedBox(width: 8),
                  Text('Current Location: Near Dhaka Junction', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Divider(color: Colors.white24, height: 20),
              Text('Next Stop: Tongi Station', style: TextStyle(color: Colors.white70, fontSize: 13)),
              SizedBox(height: 6),
              Text('Estimated Arrival: 10:45 AM', style: TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              LinearProgressIndicator(value: 0.65, backgroundColor: Colors.white12, color: Colors.greenAccent),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Prepare for Boarding', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('Speed: 65 km/h', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ২. ট্রেন বন্ধ বা নো সার্ভিস থাকলে যে ইউআই দেখাবে
  Widget _buildNoServiceUI() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
      ),
      child: const Column(
        children: [
          Icon(Icons.block, color: Colors.redAccent, size: 50),
          SizedBox(height: 12),
          Text('No Service / Train Offline', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'This train is currently not in service or scheduled off. Notification lock is enabled for this route.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}