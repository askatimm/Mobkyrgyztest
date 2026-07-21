import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class DailyLimitScreen extends StatefulWidget {
  const DailyLimitScreen({super.key});

  @override
  State<DailyLimitScreen> createState() => _DailyLimitScreenState();
}

class _DailyLimitScreenState extends State<DailyLimitScreen> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTimer();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) { 
      _updateTimer();
    });
  }

  void _updateTimer() {
    final now = DateTime.now().toUtc(); // 🔥 защита от смены времени
    final tomorrow = DateTime.utc(now.year, now.month, now.day + 1);

    if (!mounted) return;

    setState(() {
      _remaining = tomorrow.difference(now);
    });
  }

  String get formattedTime {
    final hours = _remaining.inHours.toString().padLeft(2, '0');
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F4),

      // ✅ APP BAR
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // ✅ BODY
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_clock, size: 72, color: Colors.orange),
              const SizedBox(height: 24),

              // 🔤 TITLE
              Text(
                context.tr('daily_limit_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // ⏱ TIMER
              Text(
                formattedTime,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(height: 12),

              // 🔤 SUBTITLE
              Text(
                context.tr('daily_limit_subtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 32),

              // 🔘 BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'results_close_button'.tr(),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
