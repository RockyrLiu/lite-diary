import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeTabProvider = StateProvider<int>((ref) => 0);

final selectedEntryIdProvider = StateProvider<int?>((ref) => null);

final contentDateProvider = StateProvider<DateTime?>((ref) => null);

void navigateToEntry(WidgetRef ref, int entryId) {
  ref.read(selectedEntryIdProvider.notifier).state = entryId;
  ref.read(activeTabProvider.notifier).state = 1;
}

void navigateToContentDate(WidgetRef ref, DateTime date) {
  ref.read(contentDateProvider.notifier).state = date;
  ref.read(activeTabProvider.notifier).state = 1;
}
