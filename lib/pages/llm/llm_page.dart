import 'package:flutter/material.dart';

class LlmPage extends StatelessWidget {
  final String? conversationId;

  const LlmPage({super.key, this.conversationId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LLM 对话')),
      body: const Center(child: Text('LLM 对话页 — 阶段二实现')),
    );
  }
}
