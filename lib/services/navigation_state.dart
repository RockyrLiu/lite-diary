import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeTabProvider = StateProvider<int>((ref) => 0);

final selectedEntryIdProvider = StateProvider<int?>((ref) => null);

final contentDateProvider = StateProvider<DateTime?>((ref) => null);

final settingsSubPageProvider = StateProvider<String?>((ref) => null);

void navigateToEntry(WidgetRef ref, int entryId) {
  ref.read(selectedEntryIdProvider.notifier).state = entryId;
  ref.read(activeTabProvider.notifier).state = 1;
}

void navigateToContentDate(WidgetRef ref, DateTime date) {
  ref.read(contentDateProvider.notifier).state = date;
  ref.read(activeTabProvider.notifier).state = 1;
}

void navigateToSettingsSubPage(WidgetRef ref, String subPage) {
  ref.read(settingsSubPageProvider.notifier).state = subPage;
}

void navigateToHome(WidgetRef ref) {
  ref.read(activeTabProvider.notifier).state = 0;
  ref.read(settingsSubPageProvider.notifier).state = null;
}
