import 'package:flutter/material.dart';

class SubTestButton extends StatelessWidget {
  const SubTestButton({super.key, required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // Во всю ширину отступов
      height: 60,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87, // Цвет текста
          backgroundColor: Colors.white, // Фон
          side: BorderSide(color: Colors.grey.shade400, width: 1.5), // Рамка
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2.0, // Небольшая тень
          shadowColor: Colors.grey.withOpacity(0.2),
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
