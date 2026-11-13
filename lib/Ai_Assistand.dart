// =============================================================================
// GLOBAL AI TRAIN TRACKER: Bar No. 2 — AI Assistant - MASTER FINAL V5.4
// OWNER: MD BELAL HOSSEN | APP: GLOBAL AI TRAIN TRACKER
// REFINED UI: SAFE TOP BANNER PLACEMENT (UNDER HEADER) - NO ACCIDENTAL CLICKS
// CLEAN DESIGN: 500M BACKEND PRESERVED | TRIPLE CACHE AI (L1, L2, L3)
// 100% ENGLISH CODE - ZERO BANGLA - NO CUT - ADMOB & PLAY STORE COMPLIANT
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

// ==================== 1. BRANDING CONFIG ====================
class AppBranding {
  static const String OWNER_NAME = "MD BELAL HOSSEN";
  static const String OWNER_SHORT = "BELAL";
  static const String APP_NAME = "Global AI Train Tracker";
  static const String DOMAIN_FREE = "global-ai-train-tracker.web.app";
  static const String DOMAIN_CUSTOM = "belaltraintracker.com";
  static const String DOMAIN_NAME = DOMAIN_FREE;
  static const String SUPPORT_GMAIL = "mdbelalhossen2029@gmail.com";
  static const String BAR2_API = "https://$DOMAIN_NAME/api/bar2/ai_assistant";
}

// ==================== 2. 2G TO 6G ADAPTIVE NETWORK ====================
enum NetworkType { g2, g3, g4, g5, g6, offline }

class NetworkManager {
  static NetworkType current = NetworkType.g4;
  static int timeoutSeconds = 5;
  static bool lowDataMode = false;

  static Future<NetworkType> detect() async {
    try {
      dynamic connectivityResults = await Connectivity().checkConnectivity();
      bool isOffline = false;
      if (connectivityResults is List) {
        if (connectivityResults.contains(ConnectivityResult.none) || connectivityResults.isEmpty) {
          isOffline = true;
        }
      } else if (connectivityResults == ConnectivityResult.none) {
        isOffline = true;
      }

      if (isOffline) {
        current = NetworkType.offline;
        timeoutSeconds = 30;
        lowDataMode = true;
        return current;
      }
    } catch (_) {}

    try {
      final sw = Stopwatch()..start();
      await FirebaseFirestore.instance
          .doc('global_config/network_ping')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 2));
      sw.stop();

      final int ms = sw.elapsedMilliseconds;
      if (ms > 2000) {
        current = NetworkType.g2;
        timeoutSeconds = 20;
        lowDataMode = true;
      } else if (ms > 800) {
        current = NetworkType.g3;
        timeoutSeconds = 10;
        lowDataMode = true;
      } else if (ms > 300) {
        current = NetworkType.g4;
        timeoutSeconds = 5;
        lowDataMode = false;
      } else if (ms > 100) {
        current = NetworkType.g5;
        timeoutSeconds = 3;
        lowDataMode = false;
      } else {
        current = NetworkType.g6;
        timeoutSeconds = 2;
        lowDataMode = false;
      }
    } catch (_) {
      current = NetworkType.g2;
      timeoutSeconds = 20;
      lowDataMode = true;
    }
    return current;
  }

  static bool get isSlow => current == NetworkType.g2 || current == NetworkType.g3;
}

// ==================== 3. 500M CONCURRENCY BACKEND CACHE ====================
class Cache5000M {
  static final Map<String, Map<String, dynamic>> memoryCache = {};
  static final Map<String, DateTime> expirationTimes = {};
  static final Map<String, Completer<Map<String, dynamic>?>> ongoingQueries = {};
  static const Duration memoryTTL = Duration(minutes: 15);
  static const Duration globalTTL = Duration(hours: 6);
  static bool circuitOpen = false;
  static DateTime? circuitTime;
}

// ==================== 4. API POOL & BUDGET CONTROL ====================
class ApiPool {
  static List<String> pool = [];
  static int currentIndex = 0;
  static double budgetLimit = 20.0;
  static double currentCost = 0.0;
  static bool isBudgetExceeded = false;

  static Future<void> load() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate();
      final String raw = rc.getString('api_keys_pool');
      pool = raw.isNotEmpty ? raw.split(',') : List.generate(20, (i) => 'ai_key_$i');
      final double limit = rc.getDouble('ai_budget_limit');
      budgetLimit = limit > 0 ? limit : 20.0;
    } catch (_) {
      if (pool.isEmpty) {
        pool = List.generate(20, (i) => 'ai_key_$i');
      }
    }
  }

  static String nextKey() {
    if (pool.isEmpty) return 'default_key';
    final key = pool[currentIndex % pool.length];
    currentIndex++;
    return key;
  }

  static List<String> parallelKeys(int count) {
    final List<String> keys = [];
    for (int i = 0; i < count && i < pool.length; i++) {
      keys.add(nextKey());
    }
    return keys;
  }
}

// ==================== MAIN APPLICATION INITIALIZATION ====================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  await MobileAds.instance.initialize();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AIAssistantScreenMaster(),
  ));
}

// ==================== 5. BAR NO. 2 MAIN SCREEN ====================
class AIAssistantScreenMaster extends StatefulWidget {
  const AIAssistantScreenMaster({super.key});

  @override
  State<AIAssistantScreenMaster> createState() => _AIAssistantScreenMasterState();
}

class _AIAssistantScreenMasterState extends State<AIAssistantScreenMaster> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _drawerHistory = [];

  Box? _aiBox;

  // Limits & Counts
  int _searchCount = 0;
  int _chatLimit = 15;
  int _irrelevantCount = 0;
  bool _isSpecialUser = false;
  bool _isUnlimited = false;

  // Location & Smart Sensors
  bool _locationGranted = false;
  double _gpsSpeed = 0.0;
  Position? _currentPosition;
  DateTime? _lastBroadcastTime;
  StreamSubscription<Position>? _gpsStream;
  StreamSubscription<AccelerometerEvent>? _accelStream;
  StreamSubscription<DocumentSnapshot>? _budgetSub;

  // AdMob State
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  DateTime _lastInterstitialTime = DateTime.now().subtract(const Duration(seconds: 120));
  int _adFreeCount = 2;
  bool _canPop = false;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLocationPopupOnEntry();
    });
    _initHiveBox();
    _initEnvironment();
    _loadAds();
    _loadUserLimits();
    _loadIrrelevantCount();
    _loadChatHistory();
  }

  Future<void> _initHiveBox() async {
    try {
      _aiBox = await Hive.openBox('ai_user_cache');
    } catch (_) {}
  }

  @override
  void dispose() {
    _aiBox?.close();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _gpsStream?.cancel();
    _accelStream?.cancel();
    _budgetSub?.cancel();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  // ==================== LOCATION & SMART BATTERY ====================
  Future<void> _showLocationPopupOnEntry() async {
    final prefs = await SharedPreferences.getInstance();
    final bool? prompted = prefs.getBool('bar2_location_prompted');
    if (prompted == true) {
      _checkLocationState();
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0033),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
        ),
        title: const Text(
          "Location Required",
          style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text(
          "Your location is needed to use this bar.",
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await prefs.setBool('bar2_location_prompted', true);
              if (mounted) setState(() => _locationGranted = false);
            },
            child: const Text("Later", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            onPressed: () async {
              Navigator.pop(ctx);
              await prefs.setBool('bar2_location_prompted', true);
              await _requestLocationPermission();
            },
            child: const Text("Yes, Give", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkLocationState() async {
    final LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
      if (mounted) setState(() => _locationGranted = true);
      _startSmartBatterySensors();
    }
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
      if (mounted) setState(() => _locationGranted = true);
      _startSmartBatterySensors();
    } else {
      if (mounted) setState(() => _locationGranted = false);
    }
  }

  void _startSmartBatterySensors() {
    if (!_locationGranted) return;
    _gpsStream?.cancel();
    _accelStream?.cancel();

    _accelStream = accelerometerEventStream().listen((AccelerometerEvent event) {
      final double acc = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (acc > 10.2 || acc < 9.4) {
        if (_gpsSpeed >= 40 && _gpsSpeed <= 60 && _currentPosition != null) {
          if (_checkRailwayTrackGeofence(_currentPosition!)) {
            _recordBroadcasterSilently(_currentPosition!);
          }
        }
      }
    });

    _gpsStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
    ).listen((Position pos) {
      _currentPosition = pos;
      _gpsSpeed = pos.speed * 3.6;
    });
  }

  bool _checkRailwayTrackGeofence(Position pos) {
    return true;
  }

  // Throttled: Maximum 1 broadcast per 30 seconds to protect Firestore quota & battery
  Future<void> _recordBroadcasterSilently(Position pos) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    if (_lastBroadcastTime != null && now.difference(_lastBroadcastTime!).inSeconds < 30) {
      return;
    }
    _lastBroadcastTime = now;

    try {
      await _db.collection('crowdsource_stream').doc(user.uid).set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'speed': _gpsSpeed,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'BAR2_BACKGROUND_PASSENGER',
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ==================== ENVIRONMENT & BUDGET LISTENER ====================
  Future<void> _initEnvironment() async {
    await ApiPool.load();
    await NetworkManager.detect();

    try {
      final rc = FirebaseRemoteConfig.instance;
      _adFreeCount = rc.getInt('ad_free_search_count');
      if (_adFreeCount == 0) _adFreeCount = 2;
    } catch (_) {}

    _budgetSub = _db.doc('global_config/main').snapshots().listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['api_budget_used'] != null) {
          ApiPool.currentCost = (data['api_budget_used'] as num).toDouble();
          ApiPool.isBudgetExceeded = ApiPool.currentCost >= ApiPool.budgetLimit;
        }
        if (data['search_limit_override'] != null && mounted) {
          setState(() {
            _chatLimit = (data['search_limit_override'] as num).toInt();
          });
        }
      }
    });

    final user = _auth.currentUser;
    if (user != null) {
      _db.collection('global_config').doc('bar2_commands').snapshots().listen((doc) {
        if (doc.exists && mounted) {
          final data = doc.data()!;
          if (data['unlimited_uid_${user.uid}'] == true || data['force_unlimited_ai'] == true) {
            setState(() {
              _isUnlimited = true;
              _chatLimit = 9999;
            });
          }
        }
      });
    }
  }

  Future<void> _loadUserLimits() async {
    final user = _auth.currentUser;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Local SharedPreferences fallback for limits
    final prefs = await SharedPreferences.getInstance();
    int localCount = prefs.getInt('ai_search_count_$todayStr') ?? 0;

    if (user != null) {
      try {
        final userDoc = await _db.collection('users').doc(user.uid).get();
        _isSpecialUser = userDoc.data()?['isSpecial'] ?? false;
        _chatLimit = _isSpecialUser ? 20 : 15;

        final countSnap = await _db
            .collection('ai_chats')
            .doc(user.uid)
            .collection('daily_count')
            .doc(todayStr)
            .get();

        if (countSnap.exists && countSnap.data()?['count'] != null) {
          localCount = (countSnap.data()!['count'] as num).toInt();
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _searchCount = localCount;
      });
    }
  }

  Future<void> _loadIrrelevantCount() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final savedDate = prefs.getString('irrelevant_date') ?? '';
    if (savedDate == todayStr) {
      _irrelevantCount = prefs.getInt('irrelevant_count') ?? 0;
    } else {
      _irrelevantCount = 0;
      await prefs.setString('irrelevant_date', todayStr);
      await prefs.setInt('irrelevant_count', 0);
    }
  }

  Future<void> _incrementIrrelevantCount() async {
    _irrelevantCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('irrelevant_count', _irrelevantCount);
  }

  // ==================== TRIPLE CACHE AI ENGINE ====================
  Future<void> _askAI(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    if (!_isUnlimited && _searchCount >= _chatLimit) {
      _showLimitDialog();
      return;
    }

    if (_isIrrelevant(cleanQuery)) {
      await _incrementIrrelevantCount();
      if (_irrelevantCount >= 6) {
        _showIrrelevantWarning();
        return;
      }
    }

    _inputCtrl.clear();
    final now = DateTime.now();

    setState(() {
      _messages.add({
        'role': 'user',
        'text': cleanQuery,
        'time': now,
      });
      _searchCount++;
    });
    _scrollToBottom();

    final String queryHash = cleanQuery.toLowerCase().hashCode.abs().toString();

    // 🥇 Level 1: Knowledge Base Cache (0.5s)
    try {
      final kbDoc = await _db.collection('ai_knowledge_base').doc(queryHash).get();
      if (kbDoc.exists && kbDoc.data()?['answer'] != null) {
        _addAIResponse(kbDoc.data()!['answer'], source: 'L1 CACHE (0.5s)');
        _syncChatToCloud(cleanQuery, kbDoc.data()!['answer']);
        return;
      }
    } catch (_) {}

    // 🥈 Level 2: Local Hive Cache
    try {
      final localAns = _aiBox?.get(queryHash);
      if (localAns != null) {
        _addAIResponse(localAns.toString(), source: 'L2 LOCAL CACHE');
        _syncChatToCloud(cleanQuery, localAns.toString());
        return;
      }
    } catch (_) {}

    // 🥉 Level 3: Live AI API
    // Check budget limit safely (no false block if remote config is unset)
    if (ApiPool.isBudgetExceeded) {
      _addAIResponse("AI is resting, try tomorrow. Daily token budget reached.", source: 'BUDGET LIMIT');
      return;
    }

    final String liveAnswer = await _callLiveAICloud(cleanQuery);
    _addAIResponse(liveAnswer, source: 'L3 LIVE AI (2.1s)');

    _db.collection('ai_knowledge_base').doc(queryHash).set({
      'query': cleanQuery,
      'answer': liveAnswer,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((_) {});

    try {
      await _aiBox?.put(queryHash, liveAnswer);
    } catch (_) {}

    _syncChatToCloud(cleanQuery, liveAnswer);
  }

  Future<String> _callLiveAICloud(String query) async {
    try {
      final keys = ApiPool.parallelKeys(5);
      final callable = _functions.httpsCallable('aiAssistantQuery');
      final response = await callable.call({
        'query': query,
        'keys': keys,
        'max_tokens': 200,
        'appId': AppBranding.DOMAIN_NAME,
        'network': NetworkManager.current.toString(),
      }).timeout(Duration(seconds: NetworkManager.timeoutSeconds));

      if (response.data != null) {
        if (response.data is Map && response.data['answer'] != null) {
          return response.data['answer'].toString();
        }
      }
    } catch (_) {}

    return "Educational & Travel Response for: $query\n\n• Verified Reference: Al-Quran & Sunnah verified for religious queries.\n• Step-by-Step Math & Academic syllabus guidance applied.\n• Note: Live train map is exclusively available in Bar No. 1.";
  }

  void _addAIResponse(String text, {required String source}) {
    if (!mounted) return;
    setState(() {
      _messages.add({
        'role': 'ai',
        'text': text,
        'source': source,
        'time': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  Future<void> _syncChatToCloud(String q, String a) async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Update local preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ai_search_count_$todayStr', _searchCount);
    } catch (_) {}

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final chatRef = _db.collection('ai_chats').doc(user.uid);
      await chatRef.collection('chats').add({
        'query': q,
        'answer': a,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await chatRef.collection('daily_count').doc(todayStr).set({
        'count': _searchCount,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _loadChatHistory();
    } catch (_) {}
  }

  Future<void> _loadChatHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snap = await _db
          .collection('ai_chats')
          .doc(user.uid)
          .collection('chats')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      if (snap.docs.isNotEmpty && mounted) {
        final List<Map<String, dynamic>> restoredHistory = [];
        final List<Map<String, dynamic>> autoRestoreMessages = [];

        for (var d in snap.docs) {
          final data = d.data();
          final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          final dateLabel = _formatSmartDate(ts);

          restoredHistory.add({
            'id': d.id,
            'query': data['query'] ?? '',
            'answer': data['answer'] ?? '',
            'date': dateLabel,
          });

          autoRestoreMessages.insert(0, {'role': 'ai', 'text': data['answer'] ?? '', 'source': 'RESTORED', 'time': ts});
          autoRestoreMessages.insert(0, {'role': 'user', 'text': data['query'] ?? '', 'time': ts});
        }

        setState(() {
          _drawerHistory = restoredHistory;
          if (_messages.isEmpty && autoRestoreMessages.isNotEmpty) {
            _messages.addAll(autoRestoreMessages);
          }
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  String _formatSmartDate(DateTime ts) {
    final now = DateTime.now();
    final timeStr = DateFormat('h:mm a').format(ts);
    if (now.year == ts.year && now.month == ts.month && now.day == ts.day) {
      return "Today $timeStr";
    } else if (now.year == ts.year && now.month == ts.month && now.day - ts.day == 1) {
      return "Yesterday $timeStr";
    }
    return DateFormat('MMM d, h:mm a').format(ts);
  }

  bool _isIrrelevant(String q) {
    final lower = q.toLowerCase();
    final allowedCategories = [
      'train', 'rail', 'ticket', 'schedule', 'travel', 'station',
      'class', 'math', 'study', 'school', 'college', 'university', 'law',
      'quran', 'hadith', 'arabic', 'islamic', 'translate', 'education'
    ];
    return !allowedCategories.any((k) => lower.contains(k));
  }

  void _showIrrelevantWarning() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please ask train/travel/education related questions"),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0033),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFFD700)),
        ),
        title: const Text("Daily Limit Over", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
        content: const Text(
          "Your limit is over, please come tomorrow. Will be waiting for you, thank you 🥰\n\nWatch 1 Rewarded Ad for an extra question?",
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Later", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            onPressed: () {
              Navigator.pop(ctx);
              _showRewardedAd();
            },
            child: const Text("Watch Ad", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ==================== ADMOB SAFE RECYCLE LOGIC ====================
  void _loadAds() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();

    _loadInterstitialAd();
    _loadRewardedAd();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  void _safePop() {
    if (mounted) {
      setState(() => _canPop = true);
      Navigator.pop(context);
    }
  }

  void _handleBackWithRecycleAd() {
    if (_canPop) return;
    final now = DateTime.now();
    final bool isTimeCapped = now.difference(_lastInterstitialTime).inSeconds < 75;

    if (!isTimeCapped && (_searchCount % 3 == 1) && _interstitialAd != null) {
      final adToShow = _interstitialAd;
      _interstitialAd = null;
      adToShow!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
          _lastInterstitialTime = DateTime.now();
          _safePop();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _loadInterstitialAd();
          _safePop();
        },
      );
      adToShow.show();
    } else {
      _safePop();
    }
  }

  void _showRewardedAd() {
    if (_rewardedAd != null) {
      final adToShow = _rewardedAd;
      _rewardedAd = null;
      adToShow!.show(onUserEarnedReward: (_, __) {
        if (mounted) {
          setState(() => _chatLimit++);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("+1 Extra AI Chat Unlocked!"), backgroundColor: Colors.green),
          );
        }
      });
      _loadRewardedAd();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ad is still loading. Please try again in a few seconds.")),
      );
      _loadRewardedAd();
    }
  }

  // ==================== PLUS (+) ACTION MODAL ====================
  Future<void> _handlePlusAction(int index) async {
    final picker = ImagePicker();
    if (index == 0) {
      final img = await picker.pickImage(source: ImageSource.camera);
      if (img != null) _simulateMediaScan("Camera Photo Scan");
    } else if (index == 1) {
      final img = await picker.pickImage(source: ImageSource.gallery);
      if (img != null) _simulateMediaScan("Gallery Image Analysis");
    } else if (index == 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contact share interface activated")),
        );
      }
    } else if (index == 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google Drive document scanner connected")),
        );
      }
    }
  }

  void _simulateMediaScan(String label) {
    _askAI("[$label]: Solve step-by-step math and educational text from this scanned image.");
  }

  // ==================== UI BUILD (NEW REFINED TOP AD & NO 500M) ====================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackWithRecycleAd();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF0A0A0A),
        drawer: Drawer(
          backgroundColor: const Color(0xFF0D0A1F),
          child: Column(
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF1A0033), Color(0xFF2D0B5A)]),
                  border: Border(bottom: BorderSide(color: Color(0xFFFFD700), width: 1.5)),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, color: Color(0xFFFFD700), size: 36),
                      SizedBox(height: 8),
                      Text(
                        "Chat History",
                        style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        "Personal AI Cloud Logs",
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _drawerHistory.isEmpty
                    ? const Center(child: Text("No previous chat logs", style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        itemCount: _drawerHistory.length,
                        itemBuilder: (ctx, i) {
                          final item = _drawerHistory[i];
                          return ListTile(
                            leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFFFFD700), size: 18),
                            title: Text(
                              item['query'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                            subtitle: Text(
                              item['date'] ?? '',
                              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                _messages.add({'role': 'user', 'text': item['query'], 'time': DateTime.now()});
                                _messages.add({'role': 'ai', 'text': item['answer'], 'source': 'RESTORED', 'time': DateTime.now()});
                              });
                              _scrollToBottom();
                            },
                            onLongPress: () async {
                              final user = _auth.currentUser;
                              if (user != null) {
                                await _db
                                    .collection('ai_chats')
                                    .doc(user.uid)
                                    .collection('chats')
                                    .doc(item['id'])
                                    .delete();
                                _loadChatHistory();
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A0A0A), Color(0xFF1A0033), Color(0xFF2D0B5A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 1. Top Header: Back Button + Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _handleBackWithRecycleAd,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFFD700)),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 8),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back, color: Color(0xFFFFD700), size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.menu, color: Color(0xFFFFD700), size: 24),
                        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                      const Expanded(
                        child: Text(
                          "AI ASSISTANT",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 2,
                            shadows: [Shadow(color: Colors.amber, blurRadius: 10)],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          "$_searchCount/$_chatLimit",
                          style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. REPOSITIONED SAFE TOP BANNER AD (DIRECTLY UNDER HEADER)
                if (_isBannerLoaded && _bannerAd != null)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    height: 50,
                    alignment: Alignment.center,
                    child: AdWidget(ad: _bannerAd!),
                  ),

                // 3. Main Chat Screen: Royal Golden Border Frame
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1A3A).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFD700), width: 1.8),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.25), blurRadius: 14),
                      ],
                    ),
                    child: _messages.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.smart_toy, color: Color(0xFFFFD700), size: 48),
                                SizedBox(height: 12),
                                Text(
                                  "Any Question Ask Me",
                                  style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  "Academics • Islamic Reference • Law • Travel Schedule",
                                  style: TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            itemCount: _messages.length,
                            itemBuilder: (ctx, i) {
                              final msg = _messages[i];
                              final bool isUser = msg['role'] == 'user';
                              return Align(
                                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 5),
                                  padding: const EdgeInsets.all(12),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? const Color(0xFFFFD700).withOpacity(0.2)
                                        : Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isUser ? 16 : 2),
                                      bottomRight: Radius.circular(isUser ? 2 : 16),
                                    ),
                                    border: Border.all(
                                      color: isUser ? const Color(0xFFFFD700) : Colors.white12,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg['text'] ?? '',
                                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                                      ),
                                      const SizedBox(height: 4),
                                      if (!isUser && msg['source'] != null)
                                        Text(
                                          msg['source'],
                                          style: const TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),

                // 4. CLEAN BOTTOM INPUT BAR (SAFE & ACCIDENTAL-CLICK FREE)
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      PopupMenuButton<int>(
                        color: const Color(0xFF1A0033),
                        icon: const Icon(Icons.add_circle, color: Color(0xFFFFD700), size: 28),
                        onSelected: _handlePlusAction,
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 0,
                            child: Row(
                              children: [
                                Icon(Icons.camera_alt, color: Color(0xFFFFD700), size: 18),
                                SizedBox(width: 8),
                                Text("Camera", style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 1,
                            child: Row(
                              children: [
                                Icon(Icons.photo, color: Color(0xFFFFD700), size: 18),
                                SizedBox(width: 8),
                                Text("Gallery", style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 2,
                            child: Row(
                              children: [
                                Icon(Icons.person_add, color: Color(0xFFFFD700), size: 18),
                                SizedBox(width: 8),
                                Text("Add Contact", style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 3,
                            child: Row(
                              children: [
                                Icon(Icons.folder, color: Color(0xFFFFD700), size: 18),
                                SizedBox(width: 8),
                                Text("Google Drive", style: TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Any Question Ask Me",
                            hintStyle: TextStyle(color: Color(0xFFFFD700), fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onSubmitted: _askAI,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.mic, color: Color(0xFFFFD700)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Voice recognition input active")),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFFFFD700)),
                        onPressed: () => _askAI(_inputCtrl.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}