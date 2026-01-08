import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationsService {
  static final _db = FirebaseFirestore.instance;
  static final _messaging = FirebaseMessaging.instance;

  static String? _subscribedTopic;

  static String topicForGroup(String groupId) => 'boetepot_$groupId';

  static Future<void> syncForGroup({
    required String uid,
    required String groupId,
  }) async {
    final enabled = await _isEnabled(uid);
    if (!enabled) {
      await _unsubscribeCurrent();
      return;
    }

    await _ensurePermission();
    await _messaging.getToken(); // ensures registration
    await _subscribeToGroup(groupId);
  }

  static Future<void> cleanupOnSignOut() async {
    await _unsubscribeCurrent();
  }

  static Future<void> unsubscribeCurrentTopic() async {
    await _unsubscribeCurrent();
  }

  static Future<void> _subscribeToGroup(String groupId) async {
    final topic = topicForGroup(groupId);
    if (_subscribedTopic == topic) return;

    await _unsubscribeCurrent();
    await _messaging.subscribeToTopic(topic);
    _subscribedTopic = topic;
  }

  static Future<void> _unsubscribeCurrent() async {
    final topic = _subscribedTopic;
    if (topic == null) return;
    _subscribedTopic = null;
    await _messaging.unsubscribeFromTopic(topic);
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

  static Future<bool> _isEnabled(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data() ?? const <String, dynamic>{};
    final prefs = (data['preferences'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return (prefs['notificationsEnabled'] as bool?) ?? true;
  }
}
