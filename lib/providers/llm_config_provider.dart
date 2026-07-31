import 'package:shared_preferences/shared_preferences.dart';

import '../services/llm_service.dart';
import '../services/usage_recorder.dart';

class LlmConfigService {
  static Future<Map<String, String>> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'apiUrl': prefs.getString('llm_api_url') ?? 'https://api.deepseek.com',
      'apiKey': prefs.getString('llm_api_key') ?? '',
      'model': prefs.getString('llm_model') ?? 'deepseek-v4-flash',
    };
  }

  static Future<void> saveConfig({
    required String apiUrl,
    required String apiKey,
    required String model,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('llm_api_url', apiUrl);
    await prefs.setString('llm_api_key', apiKey);
    await prefs.setString('llm_model', model);
  }

  static Future<LlmService?> buildConfiguredService() async {
    final config = await loadConfig();
    final apiUrl = config['apiUrl'] ?? '';
    final apiKey = config['apiKey'] ?? '';
    if (apiUrl.isEmpty || apiKey.isEmpty) return null;
    return LlmService(
      apiUrl: apiUrl,
      apiKey: apiKey,
      model: config['model'] ?? 'deepseek-v4-flash',
      onUsage: UsageRecorder.record,
    );
  }
}
