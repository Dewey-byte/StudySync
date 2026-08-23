import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped after any write to the database.
///
/// Read-side providers watch this, which lets an edit in one feature refresh
/// every screen that could be showing the affected data without features
/// having to import each other's providers.
final dataRevisionProvider = StateProvider<int>((ref) => 0);

extension DataRevisionRef on Ref {
  void bumpDataRevision() => read(dataRevisionProvider.notifier).state++;
}
