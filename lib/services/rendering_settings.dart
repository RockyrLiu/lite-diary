import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RenderingSettings {
  final double titleSize;
  final double bodySize;

  const RenderingSettings({this.titleSize = 24, this.bodySize = 16});

  RenderingSettings copyWith({double? titleSize, double? bodySize}) {
    return RenderingSettings(
      titleSize: titleSize ?? this.titleSize,
      bodySize: bodySize ?? this.bodySize,
    );
  }
}

final renderingSettingsProvider = StateProvider<RenderingSettings>((ref) => const RenderingSettings());

Future<RenderingSettings> loadRenderingSettings() async {
  final prefs = await SharedPreferences.getInstance();
  return RenderingSettings(
    titleSize: prefs.getDouble('render_title_size') ?? 24,
    bodySize: prefs.getDouble('render_body_size') ?? 16,
  );
}

Future<void> saveRenderingSettings(RenderingSettings s) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('render_title_size', s.titleSize);
  await prefs.setDouble('render_body_size', s.bodySize);
}
