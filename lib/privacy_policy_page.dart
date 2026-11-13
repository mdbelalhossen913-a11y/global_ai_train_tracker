// ========================================================================
// GLOBAL AI TRAIN TRACKER - INDEPENDENT PRIVACY POLICY SCREEN WIDGET
// OWNER: MD BELAL HOSSEN (mdbelalhossen2029@gmail.com)
// URL: https://globalaitraintracker.blogspot.com/2026/11/privacy-policy-global-ai-train-tracker.html
// 100% REAL - INTEGRATED OFFICIAL SHIELD LOGO - FIRESTORE SYNC - PERSISTENT
// ========================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  final bool isInitialGate;
  final VoidCallback? onAgreedCallback;

  const PrivacyPolicyScreen({
    super.key,
    this.isInitialGate = true,
    this.onAgreedCallback,
  });

  static Future<bool> checkIfAlreadyAgreed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('privacy_policy_agreed') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  static const String _ownerName = "MD BELAL HOSSEN";
  static const String _appName = "Global AI Train Tracker";
  static const String _supportEmail = "mdbelalhossen2029@gmail.com";
  static const String _bloggerPrivacyUrl =
      "https://globalaitraintracker.blogspot.com/2026/11/privacy-policy-global-ai-train-tracker.html";

  static const Color _bgColor = Color(0xFF0A0A0A);
  static const Color _cardColor = Color(0xFF121212);
  static const Color _goldColor = Color(0xFFFFD700);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  bool _isSubmitting = false;
  bool _isAgreeing = false;

  @override
  void initState() {
    super.initState();
    _prefillUserInfo();
  }

  void _prefillUserInfo() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if ((user.displayName ?? '').trim().isNotEmpty) {
          _nameCtrl.text = user.displayName!.trim();
        }
        if ((user.email ?? '').trim().isNotEmpty) {
          _emailCtrl.text = user.email!.trim();
        }
      }
    } catch (_) {
      // Safely ignore if Firebase is not initialized yet
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  void _showSnackBar(String message, {Color backgroundColor = Colors.red, Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          duration: duration,
        ),
      );
  }

  Future<void> _openBloggerPrivacy() async {
    try {
      final uri = Uri.parse(_bloggerPrivacyUrl);
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!launched) {
        _showSnackBar("Could not open Blogger privacy link");
      }
    } catch (_) {
      _showSnackBar("Could not open Blogger privacy link");
    }
  }

  Future<void> _submitAccountDeletion() async {
    if (_isSubmitting) return;

    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidateMode = AutovalidateMode.onUserInteraction);
      _showSnackBar("Please fill in your valid Name and Email");
      return;
    }

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final reason = _reasonCtrl.text.trim();
    final effectiveReason = reason.isNotEmpty ? reason : 'No reason provided';

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final String? uid = user?.uid;

      await FirebaseFirestore.instance.collection('account_deletion_requests').add({
        'name': name,
        'email': email,
        'reason': effectiveReason,
        'uid': uid,
        'appName': _appName,
        'owner': _ownerName,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      final mailUri = Uri(
        scheme: 'mailto',
        path: _supportEmail,
        query: _encodeQueryParameters({
          'subject': 'Delete My Account - $_appName',
          'body':
              'Name: $name\nEmail: $email\nReason: $effectiveReason\nUid: ${uid ?? 'Not logged in'}',
        }),
      );

      try {
        await launchUrl(mailUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Ignore if no email client is installed; Firestore request is already saved
      }

      _nameCtrl.clear();
      _emailCtrl.clear();
      _reasonCtrl.clear();

      if (mounted) {
        setState(() => _autoValidateMode = AutovalidateMode.disabled);
        _showSnackBar(
          "Request submitted successfully. Our team will process your request within 24-48 hours.",
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      _showSnackBar(
        "Submission failed: ${e.toString().replaceAll('Exception: ', '')}",
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _onYesPressed() async {
    if (_isAgreeing) return;

    setState(() => _isAgreeing = true);
    HapticFeedback.mediumImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('privacy_policy_agreed', true);
      await prefs.setString(
        'privacy_policy_agreed_at',
        DateTime.now().toIso8601String(),
      );

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'privacy_agreed': true,
            'privacy_agreed_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).catchError((_) {});
        }
      } catch (_) {
        // Non-blocking Firestore sync
      }

      if (!mounted) return;

      if (widget.onAgreedCallback != null) {
        widget.onAgreedCallback!();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      _showSnackBar("Failed to save your preference. Please try again.");
    } finally {
      if (mounted) {
        setState(() => _isAgreeing = false);
      }
    }
  }

  void _onNoPressed() {
    if (_isAgreeing) return;
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text(
              "Required",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          "You must accept the Privacy Policy to use the app.",
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Review", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.isInitialGate) {
                SystemNavigator.pop();
              } else if (Navigator.canPop(context)) {
                Navigator.pop(context, false);
              }
            },
            child: const Text(
              "Exit",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      prefixIcon: Icon(icon, color: _goldColor.withValues(alpha: 0.8), size: 18),
      filled: true,
      fillColor: Colors.black54,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _goldColor, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
    );
  }

  // Branded Official Shield Logo - 72x72 + Gold Border
  Widget _buildOfficialLogoBadge() {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _goldColor, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.5),
          child: Image.asset(
            'assets/icon/app_icon.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback if icon missing - App will NOT crash or overflow
              return Container(
                padding: const EdgeInsets.all(4),
                color: Colors.white,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "GLOBAL AI",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 7.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Text(
                        "TRAIN TRACKER",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 6.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Icon(Icons.train, color: Colors.black, size: 24),
                      const SizedBox(height: 1),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF76FF03), Color(0xFF00E5FF)],
                        ).createShader(bounds),
                        child: const Text(
                          "GAT",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isInitialGate,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.isInitialGate) {
          _onNoPressed();
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: _bgColor,
          body: SafeArea(
            child: Column(
              children: [
                // HEADER WITH EMBEDDED SHIELD LOGO
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _goldColor, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      _buildOfficialLogoBadge(),
                      const Text(
                        _appName,
                        style: TextStyle(
                          color: _goldColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Last Updated: 12 Nov 2026\nDeveloper: $_ownerName\nEmail: $_supportEmail",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // BODY CONTENT
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Play Store Description",
                            style: TextStyle(
                              color: _goldColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Train news, AI help, PNR, Prayer Times and Battery — all in one app, completely free.\n"
                            "This app is NOT an official app of any Railway authority in any country. Operated from Bangladesh.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),

                          _section(
                            "1. About This App",
                            "Global AI Train Tracker helps search trains, check schedules, get AI help, and view prayer times. Not an official app of any railway authority.",
                          ),
                          _section(
                            "2. 8 Tabs Rule",
                            "Tabs 1, 2, 3, 4, 6, 8 contain Google AdMob ads. Tabs 5 (Settings) and 7 (Support) have NO advertisements.",
                          ),
                          _section(
                            "3. Data We Collect",
                            "Name, Email, Country, Location (if allowed), Device Info & Advertising ID. We do NOT collect bank details, passwords, or call lists.",
                          ),

                          const SizedBox(height: 6),
                          const Text(
                            "Delete Account Form",
                            style: TextStyle(
                              color: _goldColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Form(
                            key: _formKey,
                            autovalidateMode: _autoValidateMode,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameCtrl,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.name],
                                  style: const TextStyle(fontSize: 12.5, color: Colors.white),
                                  decoration: _buildInputDecoration(
                                    hint: "Your Name",
                                    icon: Icons.person_outline,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return "Please enter your name";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  style: const TextStyle(fontSize: 12.5, color: Colors.white),
                                  decoration: _buildInputDecoration(
                                    hint: "Registered Email",
                                    icon: Icons.email_outlined,
                                  ),
                                  validator: (value) {
                                    final email = (value ?? '').trim().toLowerCase();
                                    if (email.isEmpty) {
                                      return "Please enter your email";
                                    }
                                    if (!_emailRegex.hasMatch(email)) {
                                      return "Enter a valid email address";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _reasonCtrl,
                                  textInputAction: TextInputAction.done,
                                  maxLines: 2,
                                  minLines: 1,
                                  style: const TextStyle(fontSize: 12.5, color: Colors.white),
                                  decoration: _buildInputDecoration(
                                    hint: "Reason (Optional)",
                                    icon: Icons.note_alt_outlined,
                                  ),
                                  onFieldSubmitted: (_) => _submitAccountDeletion(),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _goldColor,
                                      foregroundColor: Colors.black,
                                      disabledBackgroundColor: _goldColor.withValues(alpha: 0.6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: _isSubmitting ? null : _submitAccountDeletion,
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              color: Colors.black,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            "Request Account Deletion",
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          _section(
                            "4. Tickets & Payments",
                            "We do not sell tickets. We only redirect you to the official Railway website of your selected country.",
                          ),
                          _section("5. Contact Us", "Email: $_supportEmail"),

                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _openBloggerPrivacy,
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.open_in_new, color: _goldColor, size: 15),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      "View Full Policy on Blogger Website",
                                      style: TextStyle(
                                        color: _goldColor,
                                        decoration: TextDecoration.underline,
                                        decorationColor: _goldColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // BOTTOM BUTTONS
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isAgreeing ? null : _onNoPressed,
                          icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "I Do Not Agree",
                              style: TextStyle(color: Colors.white, fontSize: 12.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isAgreeing ? null : _onYesPressed,
                          icon: _isAgreeing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "I Agree",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
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

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _goldColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}