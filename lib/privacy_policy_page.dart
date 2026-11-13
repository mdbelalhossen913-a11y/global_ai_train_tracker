// ========================================================================
// GLOBAL AI TRAIN TRACKER - INDEPENDENT PRIVACY POLICY SCREEN WIDGET
// OWNER: MD BELAL HOSSEN (mdbelalhossen2029@gmail.com)
// URL: https://globalaitraintracker.blogspot.com/2026/11/privacy-policy-global-ai-train-tracker.html
// ========================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  final bool isInitialGate;
  final VoidCallback? onAgreedCallback;

  const PrivacyPolicyScreen({
    super.key,
    this.isInitialGate = true,
    this.onAgreedCallback,
  });

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  static const String _ownerName = "MD BELAL HOSSEN";
  static const String _appName = "Global AI Train Tracker";
  static const String _supportEmail = "mdbelalhossen2029@gmail.com";
  static const String _bloggerPrivacyUrl =
      "https://globalaitraintracker.blogspot.com/2026/11/privacy-policy-global-ai-train-tracker.html";

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _openBloggerPrivacy() async {
    try {
      final uri = Uri.parse(_bloggerPrivacyUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open blogger link")),
        );
      }
    }
  }

  Future<void> _submitAccountDeletion() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final reason = _reasonCtrl.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Name and Email"), backgroundColor: Colors.red),
      );
      return;
    }

    final mailUri = Uri.parse(
        "mailto:$_supportEmail?subject=Delete My Account - $_appName&body=Name: $name%0AEmail: $email%0AReason: $reason");
    try {
      await launchUrl(mailUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _onYesPressed() {
    HapticFeedback.mediumImpact();
    if (widget.onAgreedCallback != null) {
      widget.onAgreedCallback!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _onNoPressed() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text("Required", style: TextStyle(color: Colors.redAccent)),
        content: const Text("You must accept the Privacy Policy to use the app.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Review")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => SystemNavigator.pop(),
            child: const Text("Exit"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
              ),
              child: const Column(
                children: [
                  Text(
                    _appName,
                    style: TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Last Updated: 12 Nov 2026\nDeveloper: $_ownerName\nEmail: $_supportEmail",
                    style: TextStyle(color: Colors.white70, fontSize: 11),
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
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Play Store Description", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      const Text(
                        "Train news, AI help, PNR, Prayer Times and Battery — all in one app, completely free.\n"
                        "This app is NOT an official app of any Railway authority in any country. Operated from Bangladesh.",
                        style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
                      ),
                      const SizedBox(height: 14),

                      _section("1. About This App", "Global AI Train Tracker helps search trains, check schedules, get AI help, and view prayer times. Not an official app of any railway authority."),
                      _section("2. 8 Tabs Rule", "Tabs 1, 2, 3, 4, 6, 8 contain Google AdMob ads. Tabs 5 (Settings) and 7 (Support) have NO advertisements."),
                      _section("3. Data We Collect", "Name, Email, Country, Location (if allowed), Device Info & Advertising ID. We do NOT collect bank details, passwords, or call lists."),
                      
                      const SizedBox(height: 6),
                      const Text("Delete Account Form", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: "Your Name", filled: true, fillColor: Colors.black45), style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(controller: _emailCtrl, decoration: const InputDecoration(hintText: "Registered Email", filled: true, fillColor: Colors.black45), style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(controller: _reasonCtrl, decoration: const InputDecoration(hintText: "Reason (Optional)", filled: true, fillColor: Colors.black45), style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black),
                          onPressed: _submitAccountDeletion,
                          child: const Text("Request Account Deletion", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _section("4. Tickets & Payments", "We do not sell tickets. We only redirect you to the official Railway website of your selected country."),
                      _section("5. Contact Us", "Email: $_supportEmail"),
                      
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _openBloggerPrivacy,
                        child: const Text(
                          "View Full Policy on Blogger Website",
                          style: TextStyle(color: Color(0xFFFFD700), decoration: TextDecoration.underline, fontSize: 12, fontWeight: FontWeight.bold),
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
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                      onPressed: _onNoPressed,
                      child: const Text("❌ I Do Not Agree", style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
                      onPressed: _onYesPressed,
                      child: const Text("✅ I Agree", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          Text(title, style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 3),
          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35)),
        ],
      ),
    );
  }
}