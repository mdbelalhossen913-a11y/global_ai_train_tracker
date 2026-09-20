import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';

// ১. মূল অ্যাপ এন্ট্রি পয়েন্ট (যেখানে সিকিউরিটি চেক ও প্রাইভেসি পলিসি প্রথমে রান করবে)
class GlobalAiTrainTrackerApp extends StatelessWidget {
  const GlobalAiTrainTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GLOBAL AI TRAIN TRACKER',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
      ),
      home: const PrivacyPolicyCheckWrapper(),
    );
  }
}

// ২. প্রাইভেসি পলিসি ও সিকিউরিটি কনসেন্ট পেজ
class PrivacyPolicyCheckWrapper extends StatefulWidget {
  const PrivacyPolicyCheckWrapper({super.key});

  @override
  State<PrivacyPolicyCheckWrapper> createState() => _PrivacyPolicyCheckWrapperState();
}

class _PrivacyPolicyCheckWrapperState extends State<PrivacyPolicyCheckWrapper> {
  bool _isLoading = true;
  bool _isAccepted = false;

  @override
  void initState() {
    super.initState();
    _checkPrivacyConsent();
  }

  // চেক করা ইউজার আগে প্রাইভেসি পলিসিতে সম্মতি দিয়েছে কিনা
  Future<void> _checkPrivacyConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('privacy_accepted') ?? false;
    setState(() {
      _isAccepted = accepted;
      _isLoading = false;
    });
  }

  Future<void> _saveConsent(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_accepted', accepted);
    setState(() {
      _isAccepted = accepted;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
      );
    }

    // যদি ইউজার এক্সেপ্ট করে, তবে মূল ট্রেন স্ট্যাটাস পেজে প্রবেশ করবে
    if (_isAccepted) {
      return const TrainStatusPage(trainName: 'Sundarban Express (715)');
    }

    // নতুবা প্রাইভেসি পলিসি স্ক্রিন দেখাবে
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2027),
        title: const Text('Privacy & Security Verification', style: TextStyle(color: Colors.tealAccent, fontSize: 14, fontWeight: FontWeight.bold)),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade900,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security, color: Colors.tealAccent, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mandatory Privacy Check', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 2),
                          Text('Please accept terms to unlock app features.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: ListView(
                    children: const [
                      Text(
                        'GLOBAL AI TRAIN TRACKER - TERMS & PRIVACY',
                        style: TextStyle(color: Colors.tealAccent, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '1. Data Collection: We securely sync train status and device tokens via Firebase.\n\n'
                        '2. Security & Auto-Lock: Unauthorized actions will trigger device security blocks.\n\n'
                        '3. User Consent: By clicking "YES (AGREE)", you unlock all features. Selecting "NO" locks the internal features.',
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.blueGrey.shade900,
                              title: const Text('Access Denied', style: TextStyle(color: Colors.redAccent)),
                              content: const Text('You must agree to use the app features.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Colors.tealAccent))),
                              ],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                        icon: const Icon(Icons.close, color: Colors.white),
                        label: const Text('NO (DENY)', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _saveConsent(true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text('YES (AGREE)', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ৩. ট্রেন স্ট্যাটাস পেজ (ফিচার পেজ)
class TrainStatusPage extends StatefulWidget {
  final String trainName;
  const TrainStatusPage({super.key, required this.trainName});

  @override
  State<TrainStatusPage> createState() => _TrainStatusPageState();
}

class _TrainStatusPageState extends State<TrainStatusPage> {
  bool _isServiceActive = false; // উদাহরণস্বরূপ নো সার্ভিস স্ট্যাটাস

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2027),
        title: Text('Train Status: ${widget.trainName}', style: const TextStyle(color: Colors.tealAccent, fontSize: 14, fontWeight: FontWeight.bold)),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.train, color: Colors.blueAccent, size: 32),
                        const SizedBox(width: 12),
                        Text(widget.trainName, style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('SERVICE IS:', style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      _isServiceActive ? 'RUNNING ON TIME' : 'NO SERVICE',
                      style: TextStyle(color: _isServiceActive ? Colors.green : Colors.red, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red, width: 2)),
                          child: const Icon(Icons.do_not_disturb_alt, color: Colors.red, size: 40),
                        ),
                        const SizedBox(width: 20),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey, width: 2)),
                          child: const Icon(Icons.lock, color: Colors.blueGrey, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  // লগআউট বা প্রাইভেসি পারমিশন রিসেট করার অপশন
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('privacy_accepted', false);
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade800),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Reset Privacy Consent (Testing)', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}