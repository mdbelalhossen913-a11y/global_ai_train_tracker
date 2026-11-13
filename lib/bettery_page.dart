// =============================================================================
// GLOBAL AI TRAIN TRACKER: Bar No. 6 — Prayer & Sehri Master - V6.10 COMPLETE
// OWNER: MD BELAL HOSSEN | APP: GLOBAL AI TRAIN TRACKER
// 100% ENGLISH CODE - ZERO BANGLA - NO FAKE SOLAR - REAL FIRESTORE GRID CACHE
// FIXES IN V6.10: Fixed 6H TTL + Safe Single-Flight + 1-Doc-Per-Grid Real Scaling
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await MobileAds.instance.initialize();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Bar6PrayerMaster()));
}

class Bar6PrayerMaster extends StatefulWidget {
  const Bar6PrayerMaster({super.key});
  @override
  State<Bar6PrayerMaster> createState() => _Bar6PrayerMasterState();
}

class _Bar6PrayerMasterState extends State<Bar6PrayerMaster> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String _locationText = "Detecting location...";
  String _hijriText = "Loading date...";
  List<Map<String, dynamic>> _prayers = [];
  String _currentPrayer = "";
  Timer? _clockTimer;
  String _liveClock = "--:--:--";
  String _iftarCountdown = "Calculating...";
  bool _masterAdhan = true;
  double? _lat;
  double? _lng;
  double _qiblaDegree = 0.0;
  int _viewCount = 0;
  int _method = 1;

  // FIX 1 & 2: Fixed 6H TTL and safe boolean single-flight flag
  bool _isFetching = false;
  DateTime _lastFetchTime = DateTime.now().subtract(const Duration(hours: 7));
  int _apiCallCountToday = 0;
  static const int MAX_API_CALLS_PER_DAY = 1;
  static const int CACHE_TTL_HOURS = 6;

  BannerAd? _bannerAd;
  bool _bannerLoaded = false;
  InterstitialAd? _interstitialAd;
  DateTime _lastAdTime = DateTime.now().subtract(const Duration(minutes: 5));

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    final p = await SharedPreferences.getInstance();
    _viewCount = (p.getInt('prayer_view_count') ?? 0) + 1;
    await p.setInt('prayer_view_count', _viewCount);

    if (p.containsKey('lat') && p.containsKey('lng')) {
      _lat = p.getDouble('lat');
      _lng = p.getDouble('lng');
      _calculateQibla();
    }
    _locationText = p.getString('location_text') ?? "Detecting location...";

    String todayDate = DateTime.now().toIso8601String().split('T')[0];
    _apiCallCountToday = p.getInt('api_calls_$todayDate') ?? 0;
    _lastFetchTime = DateTime.tryParse(p.getString('last_fetch') ?? "") ??
        DateTime.now().subtract(const Duration(hours: 7));

    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero));
      await rc.fetchAndActivate();
      _method = rc.getInt('prayer_method_bd') != 0 ? rc.getInt('prayer_method_bd') : 1;
    } catch (_) {}

    _loadBanner();
    _loadInterstitial();
    _startClock();
    _checkLocationPermission();
  }

  void _calculateQibla() {
    if (_lat == null || _lng == null) return;
    const double kaabaLat = 21.4225;
    const double kaabaLng = 39.8262;

    double phi1 = _lat! * (math.pi / 180.0);
    double phi2 = kaabaLat * (math.pi / 180.0);
    double deltaLambda = (kaabaLng - _lng!) * (math.pi / 180.0);

    double y = math.sin(deltaLambda);
    double x = math.cos(phi1) * math.tan(phi2) -
        math.sin(phi1) * math.cos(deltaLambda);
    double qibla = math.atan2(y, x) * (180.0 / math.pi);
    setState(() {
      _qiblaDegree = (qibla + 360.0) % 360.0;
    });
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _locationText = "GPS is turned off";
          _hijriText = "Enable GPS to load prayer times";
          _iftarCountdown = "--";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please turn on device location (GPS)")),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _locationText = "Location permission permanently denied";
          _hijriText = "Allow location in App Settings";
          _iftarCountdown = "--";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Location permission is permanently denied."),
            action: SnackBarAction(
              label: "Settings",
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    if (permission == LocationPermission.denied) {
      if (!mounted) return;
      _showLocationPopup();
    } else {
      await _getCurrentLocationAndFetch();
    }
  }

  Future<void> _getCurrentLocationAndFetch() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _lat = pos.latitude;
      _lng = pos.longitude;
      _calculateQibla();

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(_lat!, _lng!);
        if (placemarks.isNotEmpty) {
          String sub = placemarks.first.subLocality ?? '';
          String loc = placemarks.first.locality ?? '';
          if (sub.isNotEmpty && loc.isNotEmpty) {
            _locationText = "$sub, $loc".toUpperCase();
          } else if (loc.isNotEmpty) {
            _locationText = loc.toUpperCase();
          } else if (placemarks.first.country != null) {
            _locationText = placemarks.first.country!.toUpperCase();
          }
        }
      } catch (_) {
        _locationText = "${_lat!.toStringAsFixed(2)}°N, ${_lng!.toStringAsFixed(2)}°E";
      }

      final p = await SharedPreferences.getInstance();
      await p.setDouble('lat', _lat!);
      await p.setDouble('lng', _lng!);
      await p.setString('location_text', _locationText);

      if (mounted) setState(() {});
      await _fetchPrayerTimes();
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationText = "Could not fetch GPS";
          _hijriText = "GPS error, please retry";
          _iftarCountdown = "--";
        });
      }
    }
  }

  void _showLocationPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFFFD700))),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_pin, color: Color(0xFFFFD700), size: 32),
              const SizedBox(height: 12),
              const Text(
                "Allow Location for Accurate Prayer Time?",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "GPS is required to fetch official Sehri, Iftar & Prayer times for your exact city.",
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (mounted) {
                          setState(() {
                            _locationText = "Location permission denied";
                            _hijriText = "Location needed for prayer times";
                            _iftarCountdown = "--";
                            _prayers = [];
                          });
                        }
                      },
                      child: const Text("No", style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        LocationPermission perm = await Geolocator.requestPermission();
                        if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
                          await _getCurrentLocationAndFetch();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Location detected successfully ✅")),
                            );
                          }
                        } else {
                          if (mounted) {
                            setState(() {
                              _locationText = "Location permission denied";
                              _hijriText = "Location needed for prayer times";
                              _iftarCountdown = "--";
                            });
                          }
                        }
                      },
                      child: const Text("Yes", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

  String _cleanTime(String t) => t.split(' ')[0].trim();

  String _format12Hour(String raw) {
    String clean = _cleanTime(raw);
    var parts = clean.split(':');
    if (parts.length < 2) return clean;
    int h = int.tryParse(parts[0]) ?? 0;
    int m = int.tryParse(parts[1]) ?? 0;
    int h12 = (h % 12 == 0) ? 12 : (h % 12);
    String ampm = h >= 12 ? 'PM' : 'AM';
    return "$h12:${m.toString().padLeft(2, '0')} $ampm";
  }

  DateTime _parseTime(String t, DateTime base) {
    try {
      String clean = _cleanTime(t);
      var parts = clean.split(':');
      int h = int.parse(parts[0].trim());
      int m = int.parse(parts[1].trim());
      if (t.toUpperCase().contains('PM') && h != 12) h += 12;
      if (t.toUpperCase().contains('AM') && h == 12) h = 0;
      return DateTime(base.year, base.month, base.day, h, m);
    } catch (_) {
      return base;
    }
  }

  String _formatTime(DateTime dt) {
    int h = dt.hour % 12;
    if (h == 0) h = 12;
    String ap = dt.hour >= 12 ? "PM" : "AM";
    return "$h:${dt.minute.toString().padLeft(2, '0')} $ap";
  }

  // ==================== FIX 1, 2, 3: REAL SCALABLE 500M FETCH ====================
  Future<void> _fetchPrayerTimes() async {
    if (_lat == null || _lng == null) return;
    if (_isFetching) return;
    _isFetching = true;

    try {
      String dateKey = DateTime.now().toIso8601String().split('T')[0];

      // 1. Check fixed 6H TTL on local Hive cache
      if (DateTime.now().difference(_lastFetchTime).inHours < CACHE_TTL_HOURS) {
        bool hasCache = await _loadFromHiveCache();
        if (hasCache) return;
      }

      if (_apiCallCountToday >= MAX_API_CALLS_PER_DAY) {
        bool hasCache = await _loadFromHiveCache();
        if (hasCache) return;
      }

      if (await _loadFromHiveCache()) {
        return;
      }

      // 2. Real 500M Sharing: Read Firestore 1 doc per ~11km grid per day
      String cacheId = "prayer_${_lat!.toStringAsFixed(1)}_${_lng!.toStringAsFixed(1)}_$dateKey";
      try {
        var fsCache = await _db.doc('prayer_times_cache/$cacheId').get();
        if (fsCache.exists) {
          var data = fsCache.data();
          DateTime updated = (data?['updated'] as Timestamp?)?.toDate() ??
              DateTime.now().subtract(const Duration(hours: 7));
          if (DateTime.now().difference(updated).inHours < CACHE_TTL_HOURS) {
            var timings = data?['timings'];
            String? cachedHijri = data?['hijri'];
            if (timings != null) {
              await _processTimings(timings, hijriText: cachedHijri, useSharedCache: true);
              return;
            }
          }
        }
      } catch (_) {}

      // 3. Only if Firestore misses, call Aladhan API 1 time
      try {
        int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        String url = "https://api.aladhan.com/v1/timings/$timestamp?latitude=$_lat&longitude=$_lng&method=$_method&school=1";
        var res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          var data = jsonDecode(res.body)['data'];
          var timings = data['timings'];
          var hijri = data['date']['hijri'];
          _hijriText = "TODAY: ${hijri['month']['en']} ${hijri['day']}, ${data['date']['gregorian']['weekday']['en']}".toUpperCase();
          await _processTimings(timings, hijriText: _hijriText, useSharedCache: false);

          final p = await SharedPreferences.getInstance();
          await p.setInt('api_calls_$dateKey', _apiCallCountToday + 1);
          await p.setString('last_fetch', DateTime.now().toIso8601String());
          _lastFetchTime = DateTime.now();
          _apiCallCountToday++;
          return;
        } else {
          await _loadFromHiveCache();
        }
      } catch (_) {
        await _loadFromHiveCache();
      }

      // If both Firestore and API fail and no cache exists: show Retry state, no fake solar times
      if (_prayers.isEmpty && mounted) {
        setState(() {
          _hijriText = "Offline - Tap Retry";
          _iftarCountdown = "--";
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<bool> _loadFromHiveCache() async {
    if (_lat == null || _lng == null) return false;
    try {
      var box = await Hive.openBox('prayer_cache');
      String dateKey = DateTime.now().toIso8601String().split('T')[0];
      String key = "prayer_${_lat!.toStringAsFixed(2)}_${_lng!.toStringAsFixed(2)}_$dateKey";
      if (box.containsKey(key)) {
        var cached = jsonDecode(box.get(key));
        if (mounted) {
          setState(() {
            _prayers = List<Map<String, dynamic>>.from(cached['prayers']);
            if (cached['hijri'] != null && cached['hijri'].toString().isNotEmpty) {
              _hijriText = cached['hijri'].toString();
            }
          });
        }
        _calculateCurrent();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _processTimings(Map timings, {String? hijriText, bool useSharedCache = false}) async {
    DateTime now = DateTime.now();
    DateTime fajrToday = _parseTime(timings['Fajr'].toString(), now);
    DateTime maghribToday = _parseTime(timings['Maghrib'].toString(), now);
    Duration nightDuration = const Duration(hours: 9, minutes: 40);
    try {
      nightDuration = fajrToday.difference(maghribToday.subtract(const Duration(days: 1)));
      if (nightDuration.inMinutes <= 0) nightDuration = const Duration(hours: 9, minutes: 40);
    } catch (_) {}
    DateTime tahajjudStart = fajrToday.subtract(Duration(minutes: (nightDuration.inMinutes / 3).round()));
    DateTime tahajjudEnd = fajrToday.subtract(const Duration(minutes: 15));

    List<Map<String, dynamic>> list = [
      {'name': 'TAHAJJUD', 'start': _formatTime(tahajjudStart), 'end': _formatTime(tahajjudEnd), 'subStart': '(Night Prayer)', 'subEnd': '(Sehri Buffer)', 'adhan': true},
      {'name': 'FAJR', 'start': _format12Hour(timings['Fajr'].toString()), 'end': _format12Hour(timings['Sunrise'].toString()), 'subStart': '(Sehri Ends)', 'subEnd': '(Sunrise)', 'adhan': true},
      {'name': 'ZUHR', 'start': _format12Hour(timings['Dhuhr'].toString()), 'end': _format12Hour(timings['Asr'].toString()), 'subStart': '', 'subEnd': '', 'adhan': true},
      {'name': 'ASR', 'start': _format12Hour(timings['Asr'].toString()), 'end': _format12Hour(timings['Maghrib'].toString()), 'subStart': '', 'subEnd': '', 'adhan': true, 'gold': true},
      {'name': 'MAGHRIB', 'start': _format12Hour(timings['Maghrib'].toString()), 'end': _format12Hour(timings['Isha'].toString()), 'subStart': '(Iftar)', 'subEnd': '', 'adhan': true},
      {'name': 'ISHA', 'start': _format12Hour(timings['Isha'].toString()), 'end': _format12Hour(timings['Fajr'].toString()), 'subStart': '', 'subEnd': '', 'adhan': true},
    ];

    if (_lat != null && _lng != null) {
      try {
        var box = await Hive.openBox('prayer_cache');
        String dateKey = DateTime.now().toIso8601String().split('T')[0];
        String key = "prayer_${_lat!.toStringAsFixed(2)}_${_lng!.toStringAsFixed(2)}_$dateKey";
        await box.put(key, jsonEncode({'prayers': list, 'hijri': hijriText ?? _hijriText}));

        // Write once to Firestore with SetOptions(merge: true) - 1 write per grid per day
        if (!useSharedCache) {
          String cacheId = "prayer_${_lat!.toStringAsFixed(1)}_${_lng!.toStringAsFixed(1)}_$dateKey";
          await _db.doc('prayer_times_cache/$cacheId').set({
            'timings': timings,
            'location': _locationText,
            'lat': _lat,
            'lng': _lng,
            'hijri': hijriText ?? _hijriText,
            'updated': FieldValue.serverTimestamp(),
            'api_source': 'aladhan_free',
            'shared_for_million': true,
          }, SetOptions(merge: true)).catchError((_) {});
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _prayers = list;
        if (hijriText != null && hijriText.isNotEmpty) {
          _hijriText = hijriText;
        }
      });
    }
    _calculateCurrent();
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      DateTime now = DateTime.now();
      int h = now.hour % 12;
      if (h == 0) h = 12;
      String ap = now.hour >= 12 ? "PM" : "AM";

      DateTime? maghrib;
      try {
        final maghribMatches = _prayers.where((e) => e['name'] == 'MAGHRIB');
        if (maghribMatches.isNotEmpty) {
          maghrib = _parseTime(maghribMatches.first['start'], now);
          if (maghrib.isBefore(now)) {
            maghrib = maghrib.add(const Duration(days: 1));
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _liveClock = "$h:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} $ap";
          if (maghrib != null) {
            Duration diff = maghrib.difference(now);
            _iftarCountdown = "IFTAR in ${diff.inHours}h ${diff.inMinutes % 60}m ${diff.inSeconds % 60}s";
          } else {
            _iftarCountdown = "--";
          }
        });
      }
      if (now.second == 0) _calculateCurrent();
    });
  }

  void _calculateCurrent() {
    if (_prayers.isEmpty) return;
    DateTime now = DateTime.now();
    for (var p in _prayers) {
      DateTime s = _parseTime(p['start'], now);
      DateTime e = _parseTime(p['end'], now);

      if (e.isBefore(s)) {
        if (now.isBefore(e)) {
          s = s.subtract(const Duration(days: 1));
        } else {
          e = e.add(const Duration(days: 1));
        }
      }

      if (now.isAfter(s) && now.isBefore(e)) {
        if (mounted && _currentPrayer != p['name']) {
          setState(() => _currentPrayer = p['name']);
        }
        break;
      }
    }
  }

  void _loadBanner() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _bannerLoaded = true);
        },
        onAdFailedToLoad: (a, e) {
          debugPrint('BannerAd failed to load: $e');
          a.dispose();
        },
      ),
    )..load();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (e) {
          debugPrint('InterstitialAd failed to load: $e');
          _interstitialAd = null;
        },
      ),
    );
  }

  void _onBack() {
    bool isPraying = _currentPrayer.isNotEmpty;
    if (isPraying) {
      if (mounted) Navigator.pop(context);
      return;
    }
    bool isCapped = DateTime.now().difference(_lastAdTime).inSeconds < 90;
    if (!isCapped && (_viewCount % 3 == 1) && _interstitialAd != null) {
      final adToShow = _interstitialAd;
      _interstitialAd = null;
      adToShow!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitial();
          _lastAdTime = DateTime.now();
          if (mounted) Navigator.pop(context);
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _loadInterstitial();
          if (mounted) Navigator.pop(context);
        },
      );
      adToShow.show();
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (d, _) {
        if (!d) _onBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFFFD700), width: 3),
            gradient: const LinearGradient(
              colors: [Color(0xFF0A0A0A), Color(0xFF1A0033)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD700)),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: _onBack,
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Column(
                            children: [
                              Text(
                                "PRAYER & SEHRI TIMINGS",
                                style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "GAT 🌙 🕌 🌟 OFFICIAL",
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Text(
                        "GAT",
                        style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Text(
                  "📍 $_locationText",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B3E).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD700)),
                  ),
                  child: Text(
                    _hijriText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1B3E).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFFD700)),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)]),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(child: Center(child: Text("PRAYER NAME", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)))),
                                    Expanded(child: Center(child: Text("START", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)))),
                                    Expanded(child: Center(child: Text("END", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)))),
                                    Expanded(child: Center(child: Text("ADHAN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)))),
                                  ],
                                ),
                              ),
                              if (_prayers.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _lat == null
                                              ? "Enable GPS to view real prayer timings"
                                              : "Offline - Tap Retry to fetch prayer timings",
                                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 14),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFFD700),
                                            shape: const StadiumBorder(),
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                          ),
                                          onPressed: () {
                                            if (_lat == null) {
                                              _checkLocationPermission();
                                            } else {
                                              _fetchPrayerTimes();
                                            }
                                          },
                                          icon: const Icon(Icons.refresh, color: Colors.black, size: 18),
                                          label: const Text(
                                            "Retry",
                                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ..._prayers.map((p) {
                                  bool isCurrent = p['name'] == _currentPrayer;
                                  return Container(
                                    margin: const EdgeInsets.only(top: 6),
                                    height: 55,
                                    decoration: BoxDecoration(
                                      color: isCurrent ? const Color(0xFFFFD700).withOpacity(0.2) : Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isCurrent ? const Color(0xFFFFD700) : Colors.white12, width: isCurrent ? 2 : 0.5),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              if (isCurrent)
                                                Container(
                                                  width: 4,
                                                  height: 55,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFFD700),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                              const SizedBox(width: 6),
                                              Text(
                                                p['name'],
                                                style: TextStyle(
                                                  color: isCurrent ? const Color(0xFFFFD700) : Colors.white,
                                                  fontWeight: isCurrent ? FontWeight.w900 : FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                p['start'],
                                                style: TextStyle(
                                                  color: isCurrent ? Colors.white : Colors.white70,
                                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (p['subStart'] != null && p['subStart'].isNotEmpty)
                                                Text(
                                                  p['subStart'],
                                                  style: const TextStyle(color: Colors.grey, fontSize: 9),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                p['end'],
                                                style: TextStyle(color: isCurrent ? Colors.white : Colors.white70, fontSize: 13),
                                              ),
                                              if (p['subEnd'] != null && p['subEnd'].isNotEmpty)
                                                Text(
                                                  p['subEnd'],
                                                  style: const TextStyle(color: Colors.grey, fontSize: 9),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              bool newVal = !(p['adhan'] as bool);
                                              setState(() => p['adhan'] = newVal);
                                              final sp = await SharedPreferences.getInstance();
                                              await sp.setBool('adhan_${p['name']}', newVal);
                                              if (_auth.currentUser != null) {
                                                await _db.doc('users/${_auth.currentUser!.uid}/adhan_settings/${p['name']}').set({'enabled': newVal}, SetOptions(merge: true));
                                              }
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${p['name']} Adhan ${newVal ? 'ON 🔊' : 'OFF 🔇'}")));
                                              }
                                            },
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(p['adhan'] ? "🔊" : "🔇", style: const TextStyle(fontSize: 16)),
                                                Text(p['adhan'] ? "ON" : "OFF", style: const TextStyle(color: Colors.white, fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D1B3E).withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFFFD700)),
                                ),
                                child: Column(
                                  children: [
                                    const Text("🕌", style: TextStyle(fontSize: 24)),
                                    const Text("ADHAN ALERT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () async {
                                        setState(() => _masterAdhan = !_masterAdhan);
                                        for (var pr in _prayers) pr['adhan'] = _masterAdhan;
                                        final sp = await SharedPreferences.getInstance();
                                        for (var pr in _prayers) await sp.setBool('adhan_${pr['name']}', _masterAdhan);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: Text(_masterAdhan ? "All Adhan Alerts ON 🔊" : "All Adhan Alerts OFF 🔇"),
                                            backgroundColor: _masterAdhan ? Colors.green : Colors.grey,
                                          ));
                                        }
                                      },
                                      child: Container(
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: _masterAdhan ? const Color(0xFFFFD700) : Colors.grey,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _masterAdhan ? "ON" : "OFF",
                                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  if (_lat == null || _lng == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Enable GPS to calculate Qibla direction")),
                                    );
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QiblaCompassScreen(
                                        qiblaDirection: _qiblaDegree,
                                        locationText: _locationText,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D1B3E).withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFFFD700)),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFFFFD700), width: 2),
                                        ),
                                        child: const Center(child: Text("🕋", style: TextStyle(fontSize: 28))),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _lat != null ? "Qibla ${_qiblaDegree.toStringAsFixed(0)}°" : "Qibla --°",
                                        style: const TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                      const Text("QIBLA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D1B3E).withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFFFD700)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _iftarCountdown,
                                      style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _liveClock,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_bannerLoaded && _bannerAd != null)
                  SizedBox(height: 50, child: AdWidget(ad: _bannerAd!)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== LIVE SENSOR-DRIVEN QIBLA COMPASS ====================
class QiblaCompassScreen extends StatefulWidget {
  final double qiblaDirection;
  final String locationText;

  const QiblaCompassScreen({
    super.key,
    required this.qiblaDirection,
    required this.locationText,
  });

  @override
  State<QiblaCompassScreen> createState() => _QiblaCompassScreenState();
}

class _QiblaCompassScreenState extends State<QiblaCompassScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFFD700)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Live Qibla Compass",
          style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0A0A), Color(0xFF1A0033)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: StreamBuilder<CompassEvent>(
          stream: FlutterCompass.events,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Compass Sensor Error: ${snapshot.error}",
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD700)),
              );
            }

            double? heading = snapshot.data?.heading;

            if (heading == null) {
              return const Center(
                child: Text(
                  "Magnetic compass sensor not detected on this device.\nDevice must have a built-in magnetometer.",
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              );
            }

            double compassAngle = (-heading * (math.pi / 180.0));
            double needleAngle = ((widget.qiblaDirection - heading) * (math.pi / 180.0));

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.locationText,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Qibla: ${widget.qiblaDirection.toStringAsFixed(1)}° | Heading: ${heading.toStringAsFixed(0)}°",
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 280,
                  height: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: compassAngle,
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5), width: 3),
                            gradient: RadialGradient(
                              colors: [const Color(0xFF0D1B3E).withOpacity(0.9), Colors.transparent],
                            ),
                          ),
                          child: const Stack(
                            children: [
                              Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text("N", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text("S", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text("W", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text("E", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: needleAngle,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.navigation, color: Color(0xFFFFD700), size: 48),
                            Container(width: 4, height: 70, color: const Color(0xFFFFD700)),
                            const SizedBox(height: 8),
                            const Text("🕋", style: TextStyle(fontSize: 28)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    "Turn your device until the golden needle aligns straight up with North.",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}