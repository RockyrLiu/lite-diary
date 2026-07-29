import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Color color;

  const SectionHeader(this.title, {super.key, this.color = Colors.lightBlue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
