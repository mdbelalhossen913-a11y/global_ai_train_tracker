import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'train_status_page.dart';

class TrainSearchPage extends ConsumerStatefulWidget {
  const TrainSearchPage({super.key});

  @override
  ConsumerState<TrainSearchPage> createState() => _TrainSearchPageState();
}

class _TrainSearchPageState extends ConsumerState<TrainSearchPage> {
  final _trainController = TextEditingController();
  final _departureController = TextEditingController();
  final _arrivalController = TextEditingController();
  String _selectedDate = 'Select Date';
  
  bool _isBotPreFetching = false;
  List<String> _botSuggestedTrains = [];
  final String _currentUserId = 'user_123';

  @override
  void initState() {
    super.initState();
    _trainController.addListener(_onUserTypingForBot);
  }

  void _onUserTypingForBot() async {
    final query = _trainController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _botSuggestedTrains = [];
        _isBotPreFetching = false;
      });
      return;
    }

    setState(() {
      _isBotPreFetching = true;
    });

    try {
      final ref = FirebaseDatabase.instance.ref('bot_pre_fetched_trains');
      final snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        List<String> matched = [];
        data.forEach((key, value) {
          String trainName = value['train_name'] ?? '';
          if (trainName.toLowerCase().contains(query.toLowerCase())) {
            matched.add(trainName);
          }
        });

        if (mounted) {
          setState(() {
            _botSuggestedTrains = matched;
            _isBotPreFetching = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _botSuggestedTrains = ['Subarna Express (701)', 'Padma Express (759)'];
            _isBotPreFetching = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBotPreFetching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _trainController.dispose();
    _departureController.dispose();
    _arrivalController.dispose();
    super.dispose();
  }

  Future<void> _handleSearchAction(String trainName) async {
    if (trainName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or type a train name!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    bool allowed = await _checkAndApplySearchLimit(_currentUserId);
    if (!allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily search limit exceeded! Controlled by Admin Panel.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TrainStatusPage(trainName: trainName),
        ),
      );
    }
  }

  Future<bool> _checkAndApplySearchLimit(String userId) async {
    try {
      final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
      
      final limitSnapshot = await dbRef.child('admin_settings/daily_search_limit').get();
      int maxLimit = 5;
      if (limitSnapshot.exists && limitSnapshot.value != null) {
        maxLimit = int.parse(limitSnapshot.value.toString());
      }

      final userSearchRef = dbRef.child('users/$userId/search_count');
      final userSnapshot = await userSearchRef.get();
      int currentCount = 0;
      if (userSnapshot.exists && userSnapshot.value != null) {
        currentCount = int.parse(userSnapshot.value.toString());
      }

      if (currentCount >= maxLimit) {
        return false;
      }

      await userSearchRef.set(currentCount + 1);
      return true;
    } catch (e) {
      return true;
    }
  }

  Future<void> _openOpenStreetMap() async {
    final Uri url = Uri.parse('https://www.openstreetmap.org');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch OpenStreetMap'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2027),
        elevation: 0,
        title: const Text('GLOBAL AI TRAIN TRACKER', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 15)),
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
          child: ListView(
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade900,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade800.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.between,
                      children: [
                        const Text('1/ Enter Train Name or Number', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                        if (_isBotPreFetching)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _trainController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.train, color: Colors.tealAccent),
                        hintText: 'Type train name (Bot Pre-fetching active)',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    if (_botSuggestedTrains.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _botSuggestedTrains.length,
                          itemBuilder: (context, index) {
                            final train = _botSuggestedTrains[index];
                            return ListTile(
                              leading: const Icon(Icons.smart_toy, color: Colors.tealAccent, size: 18),
                              title: Text(train, style: const TextStyle(color: Colors.white, fontSize: 14)),
                              subtitle: const Text('Bot pre-fetched & ready', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                              onTap: () {
                                _trainController.text = train;
                                setState(() {
                                  _botSuggestedTrains = [];
                                });
                                _handleSearchAction(train);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildSearchCard('2/ Departure Station', _departureController, 'Select Departure Station', Icons.location_on, Colors.green.shade800),
              const SizedBox(height: 14),
              _buildSearchCard('3/ Arrival Station', _arrivalController, 'Select Arrival Station', Icons.location_pin, Colors.teal.shade800),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade900,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('4/ Date of Journey', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = "${picked.day}-${picked.month}-${picked.year}";
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_selectedDate, style: const TextStyle(color: Colors.white, fontSize: 16)),
                            const Icon(Icons.calendar_today, color: Colors.tealAccent),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: () => _handleSearchAction(_trainController.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SEARCH TRAIN', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: _openOpenStreetMap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map, color: Colors.tealAccent, size: 36),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('5/ View Live Map (OpenStreetMap)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            SizedBox(height: 2),
                            Text('Real-time Click to open in real-time sync', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      ),
                      const Icon(Icons.bar_chart, color: Colors.greenAccent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard(String title, TextEditingController controller, String hint, IconData icon, Color headerColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.tealAccent),
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}