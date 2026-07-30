import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final llmApiUrlProvider = StateProvider<String>((ref) => 'https://api.deepseek.com');
final llmApiKeyProvider = StateProvider<String>((ref) => '');
final llmModelProvider = StateProvider<String>((ref) => 'deepseek-v4-flash');

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
}
