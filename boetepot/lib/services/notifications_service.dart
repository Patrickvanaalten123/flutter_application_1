import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationsService {
  static final _db = FirebaseFirestore.instance;
  static final _messaging = FirebaseMessaging.instance;

  static String? _subscribedGroupTopic;
  static String? _subscribedUserTopic;

  static String topicForGroup(String groupId) => 'boetepot_$groupId';
  static String topicForUser(String uid) => 'boetepot_user_$uid';

  static Future<void> syncForGroup({
    required String uid,
    required String groupId,
  }) async {
    await sync(uid: uid, groupId: groupId);
  }

  static Future<void> cleanupOnSignOut() async {
    await _unsubscribeAll();
  }

  static Future<void> unsubscribeCurrentTopic() async {
    await _unsubscribeAll();
  }

  static Future<void> sync({
    required String uid,
    String? groupId,
  }) async {
    final prefs = await _prefs(uid);
    if (!prefs.enabled) {
      await _unsubscribeAll();
      return;
    }

    await _ensurePermission();
    await _messaging.getToken(); // ensures registration

    if (prefs.boetesEnabled) {
      await _subscribeToUser(uid);
    } else {
      await _unsubscribeUser();
    }

    if (prefs.paymentRoundsEnabled && groupId != null && groupId.trim().isNotEmpty) {
      await _subscribeToGroup(groupId);
    } else {
      await _unsubscribeGroup();
    }
  }

  static Future<void> _subscribeToGroup(String groupId) async {
    final topic = topicForGroup(groupId);
    if (_subscribedGroupTopic == topic) return;
    await _unsubscribeGroup();
    await _messaging.subscribeToTopic(topic);
    _subscribedGroupTopic = topic;
  }

  static Future<void> _subscribeToUser(String uid) async {
    final topic = topicForUser(uid);
    if (_subscribedUserTopic == topic) return;
    await _unsubscribeUser();
    await _messaging.subscribeToTopic(topic);
    _subscribedUserTopic = topic;
  }

  static Future<void> _unsubscribeGroup() async {
    final topic = _subscribedGroupTopic;
    if (topic == null) return;
    _subscribedGroupTopic = null;
    await _messaging.unsubscribeFromTopic(topic);
  }

  static Future<void> _unsubscribeUser() async {
    final topic = _subscribedUserTopic;
    if (topic == null) return;
    _subscribedUserTopic = null;
    await _messaging.unsubscribeFromTopic(topic);
  }

  static Future<void> _unsubscribeAll() async {
    await _unsubscribeGroup();
    await _unsubscribeUser();
  }

  static Future<void> _ensurePermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      throw Exception('Meldingen zijn uitgeschakeld in je systeeminstellingen.');
    }

    // On iOS: allow showing notifications while the app is open.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<_Prefs> _prefs(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data() ?? const <String, dynamic>{};
    final prefs = (data['preferences'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final enabled = (prefs['notificationsEnabled'] as bool?) ?? true;
    final paymentRoundsEnabled = (prefs['paymentRoundNotificationsEnabled'] as bool?) ?? true;
    final boetesEnabled = (prefs['boeteNotificationsEnabled'] as bool?) ?? true;
    return _Prefs(
      enabled: enabled,
      paymentRoundsEnabled: paymentRoundsEnabled,
      boetesEnabled: boetesEnabled,
    );
  }
}

class _Prefs {
  final bool enabled;
  final bool paymentRoundsEnabled;
  final bool boetesEnabled;

  const _Prefs({
    required this.enabled,
    required this.paymentRoundsEnabled,
    required this.boetesEnabled,
  });
}
