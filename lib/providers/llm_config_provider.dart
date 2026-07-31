import 'package:shared_preferences/shared_preferences.dart';

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
