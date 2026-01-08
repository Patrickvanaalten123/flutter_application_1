import 'package:flutter/foundation.dart';
import 'group_service.dart';

class MigrationService {
  static final Set<String> _inFlight = <String>{};

  /// Ensures `userGroups/{uid}/groups/*` links exist for this user.
  /// Safe to call repeatedly; it will short-circuit once `_meta` exists.
  static Future<void> ensureUserGroupLinks(String uid) async {
    if (_inFlight.contains(uid)) return;
    _inFlight.add(uid);
    try {
      final svc = GroupService();
      final already = await svc.hasMigratedLinks(uid);
      if (already) return;

      await svc.migrateLinksForUser(uid);
      await svc.markLinksMigrated(uid);
      debugPrint('✅ userGroups migration complete for $uid');
    } catch (e) {
      debugPrint('⚠️ userGroups migration failed for $uid: $e');
    } finally {
      _inFlight.remove(uid);
    }
  }
}

