import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoURL;
  final String? phone;
  final String? preferredGroupId;
  final UserPreferences preferences;

  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoURL,
    this.phone,
    this.preferredGroupId,
    this.preferences = const UserPreferences(),
  });

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppUser(
      id: doc.id,
      email: (d['email'] as String?) ?? '',
      displayName: d['displayName'] as String?,
      photoURL: d['photoURL'] as String?,
      phone: d['phone'] as String?,
      preferredGroupId: d['preferredGroupId'] as String?,
      preferences: UserPreferences.fromMap(d['preferences'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        if (displayName != null) 'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
        if (phone != null) 'phone': phone,
        if (preferredGroupId != null) 'preferredGroupId': preferredGroupId,
        'preferences': preferences.toMap(),
      };

  AppUser copyWith({
    String? displayName,
    String? photoURL,
    String? preferredGroupId,
    UserPreferences? preferences,
  }) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      phone: phone,
      preferredGroupId: preferredGroupId ?? this.preferredGroupId,
      preferences: preferences ?? this.preferences,
    );
  }
}

class UserPreferences {
  final bool notificationsEnabled;
  final bool paymentRoundNotificationsEnabled;
  final bool boeteNotificationsEnabled;
  final String? locale;
  final String? currencyCode;

  const UserPreferences({
    this.notificationsEnabled = true,
    this.paymentRoundNotificationsEnabled = true,
    this.boeteNotificationsEnabled = true,
    this.locale,
    this.currencyCode = 'EUR',
  });

  factory UserPreferences.fromMap(Map<String, dynamic>? map) {
    final m = map ?? const <String, dynamic>{};
    return UserPreferences(
      notificationsEnabled: (m['notificationsEnabled'] as bool?) ?? true,
      paymentRoundNotificationsEnabled: (m['paymentRoundNotificationsEnabled'] as bool?) ?? true,
      boeteNotificationsEnabled: (m['boeteNotificationsEnabled'] as bool?) ?? true,
      locale: m['locale'] as String?,
      currencyCode: m['currencyCode'] as String? ?? 'EUR',
    );
  }

  Map<String, dynamic> toMap() => {
        'notificationsEnabled': notificationsEnabled,
        'paymentRoundNotificationsEnabled': paymentRoundNotificationsEnabled,
        'boeteNotificationsEnabled': boeteNotificationsEnabled,
        if (locale != null) 'locale': locale,
        if (currencyCode != null) 'currencyCode': currencyCode,
      };
}

class BoetePotGroup {
  final String id;
  final String name;
  final List<String> members; // uids
  final Map<String, String> roles; // uid -> role

  BoetePotGroup({
    required this.id,
    required this.name,
    required this.members,
    required this.roles,
  });

  factory BoetePotGroup.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return BoetePotGroup(
      id: doc.id,
      name: (d['name'] as String?) ?? '',
      members: (d['members'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      roles: (d['roles'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? const {},
    );
  }
}

class GroupLink {
  final String groupId;
  final String name;
  final String? role;
  final int? memberCount;

  GroupLink({
    required this.groupId,
    required this.name,
    this.role,
    this.memberCount,
  });

  factory GroupLink.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return GroupLink(
      groupId: doc.id,
      name: (d['name'] as String?) ?? '',
      role: d['role'] as String?,
      memberCount: (d['memberCount'] as num?)?.toInt(),
    );
  }
}

class Boete {
  final String id;
  final String groupId;
  final String title;
  final String description;
  final double amount;
  final String userEmail; // creator
  final String assignedToUid;
  final String? assignedToEmail;
  final DateTime dateAdded;

  Boete({
    required this.id,
    required this.groupId,
    required this.title,
    required this.description,
    required this.amount,
    required this.userEmail,
    required this.assignedToUid,
    required this.dateAdded,
    this.assignedToEmail,
  });

  factory Boete.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Boete(
      id: doc.id,
      groupId: (d['groupId'] as String?) ?? '',
      title: (d['title'] as String?) ?? '',
      description: (d['description'] as String?) ?? '',
      amount: ((d['amount'] as num?) ?? 0).toDouble(),
      userEmail: (d['userEmail'] as String?) ?? '',
      assignedToUid: (d['assignedToUid'] as String?) ?? '',
      assignedToEmail: d['assignedToEmail'] as String?,
      dateAdded: (d['dateAdded'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class BoeteTemplate {
  final String id;
  final String groupId;
  final String title;
  final String description;
  final double amount;
  final String createdBy;
  final bool isActive;

  BoeteTemplate({
    required this.id,
    required this.groupId,
    required this.title,
    required this.description,
    required this.amount,
    required this.createdBy,
    required this.isActive,
  });

  factory BoeteTemplate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return BoeteTemplate(
      id: doc.id,
      groupId: (d['groupId'] as String?) ?? '',
      title: (d['title'] as String?) ?? '',
      description: (d['description'] as String?) ?? '',
      amount: ((d['amount'] as num?) ?? 0).toDouble(),
      createdBy: (d['createdBy'] as String?) ?? '',
      isActive: (d['isActive'] as bool?) ?? true,
    );
  }
}

class PaymentRound {
  final String id;
  final String groupId;
  final Timestamp createdAt;
  final String createdBy;
  final String status; // "open" | "closed"
  final String? note;
  final String? paymentLink;
  final Timestamp asOf;

  PaymentRound({
    required this.id,
    required this.groupId,
    required this.createdAt,
    required this.createdBy,
    required this.status,
    required this.asOf,
    this.note,
    this.paymentLink,
  });

  factory PaymentRound.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PaymentRound(
      id: doc.id,
      groupId: (d['groupId'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?) ?? Timestamp.now(),
      createdBy: (d['createdBy'] as String?) ?? '',
      status: (d['status'] as String?) ?? 'open',
      note: d['note'] as String?,
      paymentLink: d['paymentLink'] as String?,
      asOf: (d['asOf'] as Timestamp?) ?? Timestamp.now(),
    );
  }

  PaymentRound copyWith({
    String? status,
    String? note,
    String? paymentLink,
  }) {
    return PaymentRound(
      id: id,
      groupId: groupId,
      createdAt: createdAt,
      createdBy: createdBy,
      status: status ?? this.status,
      note: note ?? this.note,
      paymentLink: paymentLink ?? this.paymentLink,
      asOf: asOf,
    );
  }
}

class PaymentObligation {
  final String id; // uid
  final String uid;
  final String? email;
  final String? displayName;
  final double amount;
  final bool paid;
  final Timestamp? paidAt;
  final String? markedByUid;

  PaymentObligation({
    required this.id,
    required this.uid,
    required this.amount,
    required this.paid,
    this.email,
    this.displayName,
    this.paidAt,
    this.markedByUid,
  });

  factory PaymentObligation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PaymentObligation(
      id: doc.id,
      uid: (d['uid'] as String?) ?? doc.id,
      email: d['email'] as String?,
      displayName: d['displayName'] as String?,
      amount: ((d['amount'] as num?) ?? 0).toDouble(),
      paid: (d['paid'] as bool?) ?? false,
      paidAt: d['paidAt'] as Timestamp?,
      markedByUid: d['markedByUid'] as String?,
    );
  }
}
