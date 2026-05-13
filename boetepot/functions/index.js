const admin = require("firebase-admin");
const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const crypto = require("crypto");
const {defineSecret} = require("firebase-functions/params");

admin.initializeApp();

// Keep the function in the same region as Firestore/Eventarc.
setGlobalOptions({maxInstances: 10, region: "europe-west2"});

const PAYMENT_ROUND_PATH = "paymentRounds/{roundId}";
const BOETE_PATH = "boetes/{boeteId}";
const ACCOUNT_DELETION_REQUEST_PATH = "accountDeletionRequests/{requestId}";

/**
 * Deletes documents for the given query in batches.
 * @param {FirebaseFirestore.Query<FirebaseFirestore.DocumentData>} query
 * @param {number} batchSize
 * @return {Promise<void>}
 */
async function deleteQueryInBatches(query, batchSize = 450) {
  let done = false;
  while (!done) {
    const snap = await query.limit(batchSize).get();
    if (snap.empty) {
      done = true;
      continue;
    }
    const batch = admin.firestore().batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

/**
 * Deletes all `payments` subcollection documents for a list of payment rounds.
 * @param {Array<FirebaseFirestore.QueryDocumentSnapshot>} roundDocs
 * @return {Promise<void>}
 */
async function deletePaymentsSubcollections(roundDocs) {
  for (const doc of roundDocs) {
    await deleteQueryInBatches(doc.ref.collection("payments"));
  }
}

/**
 * Deletes a BoetePot and its related data.
 * Only the group creator or an admin may delete.
 */
exports.deleteBoetepot = onCall({timeoutSeconds: 540}, async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Je bent niet ingelogd.");
    }
    const groupId = String((request.data && request.data.groupId) || "").trim();
    if (!groupId) {
      throw new HttpsError("invalid-argument", "groupId is verplicht.");
    }

    const db = admin.firestore();
    const groupRef = db.collection("groups").doc(groupId);
    const groupSnap = await groupRef.get();
    if (!groupSnap.exists) {
      throw new HttpsError("not-found", "BoetePot bestaat niet (meer).");
    }

    const g = groupSnap.data() || {};
    const createdBy = String(g.createdBy || "");
    const members = Array.isArray(g.members) ? g.members.map(String) : [];
    const roles = g.roles || {};
    const email = request.auth.token && request.auth.token.email ?
      String(request.auth.token.email) :
      "";
    const role = String(roles[request.auth.uid] || roles[email] || "member");

    if (request.auth.uid !== createdBy && role !== "admin") {
      throw new HttpsError(
          "permission-denied",
          "Je hebt geen rechten om deze BoetePot te verwijderen.",
      );
    }

    logger.info("Deleting BoetePot", {
      groupId: groupId,
      requestedBy: request.auth.uid,
    });

    logger.info("Delete boetes start", {groupId: groupId});
    await deleteQueryInBatches(
        db.collection("boetes").where("groupId", "==", groupId),
    );
    logger.info("Delete boetes done", {groupId: groupId});

    logger.info("Delete templates start", {groupId: groupId});
    await deleteQueryInBatches(
        db.collection("boeteTemplates").where("groupId", "==", groupId),
    );
    logger.info("Delete templates done", {groupId: groupId});

    const roundsQuery = db
        .collection("paymentRounds")
        .where("groupId", "==", groupId);
    const roundsSnap = await roundsQuery.get();
    logger.info("Delete payment rounds start", {
      groupId: groupId,
      rounds: roundsSnap.size,
    });
    await deletePaymentsSubcollections(roundsSnap.docs);
    await deleteQueryInBatches(roundsQuery);
    logger.info("Delete payment rounds done", {
      groupId: groupId,
      rounds: roundsSnap.size,
    });

    // Remove user->group link docs for all known members (safe & fast).
    let deletedLinks = 0;
    if (members.length > 0) {
      logger.info("Delete user group links start", {
        groupId: groupId,
        members: members.length,
      });
      const batchSize = 450;
      for (let i = 0; i < members.length; i += batchSize) {
        const batch = db.batch();
        const chunk = members.slice(i, i + batchSize);
        chunk.forEach((uid) => {
          const linkRef = db
              .collection("userGroups")
              .doc(String(uid))
              .collection("groups")
              .doc(groupId);
          batch.delete(linkRef);
        });
        await batch.commit();
        deletedLinks += chunk.length;
      }
      logger.info("Delete user group links done", {
        groupId: groupId,
        deletedLinks: deletedLinks,
      });
    }

    logger.info("Delete group doc start", {groupId: groupId});
    await groupRef.delete();
    logger.info("Delete group doc done", {groupId: groupId});

    logger.info("Deleted BoetePot", {groupId: groupId});
    return {
      ok: true,
      deletedLinks: deletedLinks,
      deletedRounds: roundsSnap.size,
    };
  } catch (err) {
    logger.error("deleteBoetepot failed", {err: String(err)});
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("internal", "Verwijderen mislukt. Probeer opnieuw.");
  }
});

/**
 * @param {Date} date
 * @return {string}
 */
function formatMonthYear(date) {
  try {
    return new Intl.DateTimeFormat("nl-NL", {
      month: "long",
      year: "numeric",
    }).format(date);
  } catch (_) {
    return `${date.getMonth() + 1}-${date.getFullYear()}`;
  }
}

/**
 * Sends an FCM notification to all members of a BoetePot when a new payment
 * round is created.
 *
 * Clients subscribe to the topic: `boetepot_{groupId}`.
 */
/**
 * @param {object} event CloudEvent from Firestore trigger.
 * @return {Promise<void>}
 */
async function handlePaymentRoundCreated(event) {
  const snap = event.data;
  if (!snap) return;

  const data = snap.data() || {};
  const groupId = data.groupId;
  if (!groupId) {
    logger.warn("paymentRounds doc missing groupId", {roundId: snap.id});
    return;
  }

  let groupName = "BoetePot";
  try {
    const groupSnap = await admin
        .firestore()
        .collection("groups")
        .doc(String(groupId))
        .get();
    const g = groupSnap.data() || {};
    if (typeof g.name === "string" && g.name.trim()) {
      groupName = g.name.trim();
    }
  } catch (e) {
    logger.warn(
        "Failed to load group name for payment round notification",
        {groupId: String(groupId), err: String(e)},
    );
  }

  const note = typeof data.note === "string" ? data.note.trim() : "";

  let asOfLabel = "";
  const asOf = data.asOf;
  if (asOf && typeof asOf.toDate === "function") {
    asOfLabel = formatMonthYear(asOf.toDate());
  }

  const title = "Nieuwe betaalronde";
  const subtitle = note || (asOfLabel ? `Stand ${asOfLabel}` : "");
  const body = subtitle ? `${groupName} — ${subtitle}` : groupName;
  const topic = `boetepot_${groupId}`;

  await admin.messaging().send({
    topic: topic,
    notification: {title: title, body: body},
    data: {
      type: "paymentRoundStarted",
      groupId: String(groupId),
      roundId: String(snap.id),
    },
  });

  logger.info(
      "Sent payment round notification",
      {groupId: String(groupId), roundId: snap.id},
  );
}

exports.onPaymentRoundCreated = onDocumentCreated(
    PAYMENT_ROUND_PATH,
    handlePaymentRoundCreated,
);

/**
 * Sends an FCM notification to the assignee when a new boete is created.
 *
 * Clients subscribe to the topic: `boetepot_user_{uid}`.
 */
/**
 * @param {object} event CloudEvent from Firestore trigger.
 * @return {Promise<void>}
 */
async function handleBoeteCreated(event) {
  const snap = event.data;
  if (!snap) return;

  const data = snap.data() || {};
  const groupId = data.groupId;
  const assignedToUid = data.assignedToUid;
  if (!assignedToUid) {
    return;
  }

  let groupName = "BoetePot";
  if (groupId) {
    try {
      const groupSnap = await admin
          .firestore()
          .collection("groups")
          .doc(String(groupId))
          .get();
      const g = groupSnap.data() || {};
      if (typeof g.name === "string" && g.name.trim()) {
        groupName = g.name.trim();
      }
    } catch (e) {
      logger.warn(
          "Failed to load group name for boete notification",
          {groupId: String(groupId), err: String(e)},
      );
    }
  }

  const title = "Je hebt een boete gekregen";
  const body = `Je hebt een boete gekregen vanuit deze boetepot app. ` +
      `(${groupName})`;
  const topic = `boetepot_user_${assignedToUid}`;

  await admin.messaging().send({
    topic: topic,
    notification: {title: title, body: body},
    data: {
      type: "boeteAssigned",
      groupId: groupId ? String(groupId) : "",
      boeteId: String(snap.id),
      assignedToUid: String(assignedToUid),
    },
  });

  logger.info("Sent boete notification", {
    boeteId: snap.id,
    groupId: groupId ? String(groupId) : "",
    assignedToUid: String(assignedToUid),
  });
}

exports.onBoeteCreated = onDocumentCreated(
    BOETE_PATH,
    handleBoeteCreated,
);

/**
 * Performs a full account deletion for the given uid (server-side).
 *
 * - Removes the user from all groups.
 * - Deletes `users/{uid}` and `userGroups/{uid}/groups/*`.
 * - Deletes profile photo `userphotos/{uid}.jpg` (best-effort).
 * - Removes the user's payment obligation docs from
 *   `paymentRounds/{roundId}/payments/{uid}` (best-effort).
 * - Anonymizes email fields in historical docs (best-effort).
 * - Deletes the Firebase Auth user.
 */
async function performAccountDeletion({
  uid,
  requestId,
}) {
  const db = admin.firestore();

  // Make the operation idempotent.
  try {
    await admin.auth().getUser(uid);
  } catch (e) {
    const msg = String(e);
    if (msg.includes("auth/user-not-found")) return;
  }

  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  const userData = userSnap.data() || {};
  const email = typeof userData.email === "string" ?
      userData.email.trim().toLowerCase() :
      "";

  // Discover groups via userGroups links (fast) with a membership fallback.
  const groupIds = new Set();
  try {
    const linksSnap = await db
        .collection("userGroups")
        .doc(uid)
        .collection("groups")
        .get();
    linksSnap.docs.forEach((d) => {
      if (d.id !== "_meta") groupIds.add(d.id);
    });
  } catch (e) {
    logger.warn(
        "Failed to read userGroups links during account deletion",
        {uid: uid, err: String(e)},
    );
  }

  try {
    const groupsSnap = await db
        .collection("groups")
        .where("members", "array-contains", uid)
        .get();
    groupsSnap.docs.forEach((d) => groupIds.add(d.id));
  } catch (e) {
    logger.warn(
        "Failed to query groups membership during account deletion",
        {uid: uid, err: String(e)},
    );
  }

  logger.info("Deleting account", {uid: uid, groups: groupIds.size});

  // Remove the user from groups; ensure at least one admin remains.
  for (const groupId of groupIds) {
    const groupRef = db.collection("groups").doc(String(groupId));
    const groupSnap = await groupRef.get();
    if (!groupSnap.exists) continue;
    const g = groupSnap.data() || {};

    const members = Array.isArray(g.members) ? g.members.map(String) : [];
    const rolesRaw = g.roles && typeof g.roles === "object" ? g.roles : {};
    const roles = {...rolesRaw};

    const newMembers = members.filter((m) => m !== uid);
    if (roles[uid] !== undefined) delete roles[uid];

    // If the group becomes empty, clean it up entirely (user-owned data).
    if (newMembers.length === 0) {
      logger.info("Deleting empty group during account deletion", {
        uid: uid,
        groupId: String(groupId),
      });

      await deleteQueryInBatches(
          db.collection("boetes").where("groupId", "==", String(groupId)),
      );
      await deleteQueryInBatches(
          db
              .collection("boeteTemplates")
              .where("groupId", "==", String(groupId)),
      );

      const roundsQuery = db
          .collection("paymentRounds")
          .where("groupId", "==", String(groupId));
      const roundsSnap = await roundsQuery.get();
      await deletePaymentsSubcollections(roundsSnap.docs);
      await deleteQueryInBatches(roundsQuery);

      await groupRef.delete();
      continue;
    }

    let createdBy = typeof g.createdBy === "string" ? g.createdBy : "";
    let creatorChanged = false;

    // If the user was the creator, reassign to an admin or first member.
    if (createdBy === uid) {
      const adminUid = newMembers.find(
          (m) => String(roles[m] || "") === "admin",
      );
      createdBy = adminUid || (newMembers[0] || "");
      creatorChanged = true;
    }

    // Ensure at least one admin remains if the group still has members.
    const hasAdmin = newMembers.some(
        (m) => String(roles[m] || "") === "admin",
    );
    if (newMembers.length > 0 && !hasAdmin) {
      roles[newMembers[0]] = "admin";
      if (!createdBy) {
        createdBy = newMembers[0];
        creatorChanged = true;
      }
    }

    const batch = db.batch();
    batch.update(groupRef, {
      members: newMembers,
      roles: roles,
      ...(creatorChanged ? {createdBy: createdBy} : {}),
    });

    // Update memberCount in link docs for remaining members (best-effort).
    const memberCount = newMembers.length;
    for (const memberUid of newMembers) {
      const linkRef = db
          .collection("userGroups")
          .doc(String(memberUid))
          .collection("groups")
          .doc(String(groupId));
      batch.set(linkRef, {memberCount: memberCount}, {merge: true});
    }

    // Remove the link doc for the deleting user.
    const myLinkRef = db
        .collection("userGroups")
        .doc(uid)
        .collection("groups")
        .doc(String(groupId));
    batch.delete(myLinkRef);

    await batch.commit();
  }

  // Remove payment obligation docs for this uid (best-effort).
  try {
    await deleteQueryInBatches(
        db.collectionGroup("payments").where("uid", "==", uid),
    );
  } catch (e) {
    logger.warn("Failed to delete payments via collectionGroup", {
      uid: uid,
      requestId: requestId || "",
      err: String(e),
    });
  }

  // Best-effort anonymization of historical docs that store raw emails.
  const anon = "verwijderde-gebruiker";
  if (email) {
    let done = false;
    while (!done) {
      const snap = await db
          .collection("boetes")
          .where("userEmail", "==", email)
          .limit(400)
          .get();
      if (snap.empty) {
        done = true;
        continue;
      }
      const batch = db.batch();
      snap.docs.forEach((d) => batch.update(d.ref, {userEmail: anon}));
      await batch.commit();
    }

    done = false;
    while (!done) {
      const snap = await db
          .collection("boeteTemplates")
          .where("createdBy", "==", email)
          .limit(400)
          .get();
      if (snap.empty) {
        done = true;
        continue;
      }
      const batch = db.batch();
      snap.docs.forEach((d) => batch.update(d.ref, {createdBy: anon}));
      await batch.commit();
    }
  }

  // Remove assignedToEmail for boetes that were assigned to this uid.
  let assignedDone = false;
  while (!assignedDone) {
    const snap = await db
        .collection("boetes")
        .where("assignedToUid", "==", uid)
        .limit(400)
        .get();
    if (snap.empty) {
      assignedDone = true;
      continue;
    }
    const batch = db.batch();
    snap.docs.forEach((d) => batch.update(d.ref, {
      assignedToEmail: admin.firestore.FieldValue.delete(),
    }));
    await batch.commit();
  }

  // Delete userGroups subcollection docs (if any remain).
  try {
    await deleteQueryInBatches(
        db.collection("userGroups").doc(uid).collection("groups"),
    );
  } catch (e) {
    logger.warn(
        "Failed to delete userGroups links subcollection",
        {uid: uid, err: String(e)},
    );
  }
  await db.collection("userGroups").doc(uid).delete().catch(() => null);

  // Delete user doc.
  await userRef.delete().catch(() => null);

  // Delete profile photo from Storage (best-effort).
  try {
    const bucket = admin.storage().bucket();
    await bucket.file(`userphotos/${uid}.jpg`).delete();
  } catch (e) {
    const msg = String(e);
    if (!msg.includes("No such object") && !msg.includes("404")) {
      logger.warn("Failed to delete profile photo", {uid: uid, err: msg});
    }
  }

  // Delete the Firebase Auth user last.
  await admin.auth().deleteUser(uid);

  logger.info("Deleted account", {uid: uid});
}

/**
 * Enqueues an account deletion request document.
 * @param {{uid: string, source: string}} params
 * @return {Promise<string>} requestId
 */
async function enqueueAccountDeletion({
  uid,
  source,
}) {
  const db = admin.firestore();
  const ref = db.collection("accountDeletionRequests").doc();
  await ref.set({
    uid: String(uid),
    source: String(source || "unknown"),
    status: "pending",
    requestedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return ref.id;
}

/**
 * Request account deletion for the currently authenticated user.
 *
 * Important: this returns quickly and performs the heavy cleanup in a
 * background Firestore-triggered function to avoid client timeouts.
 */
exports.deleteMyAccount = onCall({timeoutSeconds: 60}, async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Je bent niet ingelogd.");
    }
    const uid = String(request.auth.uid);

    // Disable immediately (best-effort) to prevent re-login while deleting.
    try {
      await admin.auth().updateUser(uid, {disabled: true});
    } catch (e) {
      logger.warn("Failed to disable user during deletion request", {
        uid: uid,
        err: String(e),
      });
    }

    const requestId = await enqueueAccountDeletion({
      uid: uid,
      source: "callable",
    });
    logger.info("Queued account deletion", {uid: uid, requestId: requestId});
    return {ok: true, requestId: requestId};
  } catch (err) {
    logger.error("deleteMyAccount failed", {err: String(err)});
    if (err instanceof HttpsError) throw err;
    throw new HttpsError(
        "internal",
        "Account verwijderen mislukt. Probeer opnieuw.",
    );
  }
});

exports.onAccountDeletionRequested = onDocumentCreated(
    {document: ACCOUNT_DELETION_REQUEST_PATH, timeoutSeconds: 540},
    async (event) => {
      const snap = event.data;
      if (!snap) return;
      const data = snap.data() || {};
      const uid = String(data.uid || "").trim();
      if (!uid) {
        logger.warn(
            "accountDeletionRequests missing uid",
            {requestId: snap.id},
        );
        return;
      }

      const ref = snap.ref;
      await ref.set({
        status: "running",
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      try {
        await performAccountDeletion({uid: uid, requestId: snap.id});
        await ref.set({
          status: "done",
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      } catch (e) {
        logger.error("Account deletion background job failed", {
          requestId: snap.id,
          uid: uid,
          err: String(e),
        });
        await ref.set({
          status: "failed",
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
          error: String(e).slice(0, 500),
        }, {merge: true});
      }
    },
);

// -------------------------
// Mollie (Connect) payments
// -------------------------

const MOLLIE_OAUTH_AUTHORIZE_URL = "https://www.mollie.com/oauth2/authorize";
const MOLLIE_OAUTH_TOKEN_URL = "https://api.mollie.com/oauth2/tokens";
const MOLLIE_API_BASE = "https://api.mollie.com/v2";

const MOLLIE_CLIENT_ID = defineSecret("MOLLIE_CLIENT_ID");
const MOLLIE_CLIENT_SECRET = defineSecret("MOLLIE_CLIENT_SECRET");
const MOLLIE_REDIRECT_URL = defineSecret("MOLLIE_REDIRECT_URL");
const MOLLIE_PAYMENT_REDIRECT_URL = defineSecret("MOLLIE_PAYMENT_REDIRECT_URL");
const MOLLIE_WEBHOOK_URL = defineSecret("MOLLIE_WEBHOOK_URL");

/**
 * @param {number} cents
 * @return {string}
 */
function eurValue(cents) {
  return (Math.round(cents) / 100).toFixed(2);
}

/**
 * Fee policy:
 * - Fee is above the base amount.
 * - Base >= €100: 1%
 * - Otherwise: 3%
 * - Minimum fee: €1
 *
 * @param {number} baseCents
 * @return {number} feeCents
 */
function computeFeeCents(baseCents) {
  const pct = baseCents >= 10000 ? 0.01 : 0.03;
  const fee = Math.round(baseCents * pct);
  return Math.max(100, fee);
}

/**
 * @param {any} secretParam
 * @param {string} name
 * @return {string}
 */
function requireSecret(secretParam, name) {
  const v = secretParam.value() || process.env[name];
  if (!v || !String(v).trim()) {
    throw new HttpsError(
        "failed-precondition",
        `Serverconfig ontbreekt: ${name}`,
    );
  }
  return String(v).trim();
}

/**
 * @param {string} token
 * @param {string} path
 * @return {Promise<any>}
 */
async function mollieGet(token, path) {
  const res = await fetch(`${MOLLIE_API_BASE}${path}`, {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
    },
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`Mollie GET ${path} failed: ${res.status} ${text}`);
  }
  return JSON.parse(text);
}

/**
 * @param {string} token
 * @param {string} path
 * @param {object} body
 * @return {Promise<any>}
 */
async function molliePost(token, path, body) {
  const res = await fetch(`${MOLLIE_API_BASE}${path}`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`Mollie POST ${path} failed: ${res.status} ${text}`);
  }
  return JSON.parse(text);
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} groupId
 * @param {string} uid
 * @param {string} email
 * @return {Promise<void>}
 */
async function assertGroupAdmin(db, groupId, uid, email) {
  const groupSnap = await db.collection("groups").doc(groupId).get();
  if (!groupSnap.exists) {
    throw new HttpsError("not-found", "BoetePot bestaat niet (meer).");
  }
  const g = groupSnap.data() || {};
  const createdBy = String(g.createdBy || "");
  const roles = g.roles || {};
  const role = String(roles[uid] || roles[email] || "member");
  if (uid !== createdBy && role !== "admin") {
    throw new HttpsError(
        "permission-denied",
        "Alleen een admin kan Mollie koppelen.",
    );
  }
}

/**
 * @param {string} clientId
 * @param {string} redirectUrl
 * @param {string} state
 * @return {string}
 */
function buildMollieAuthorizeUrl(clientId, redirectUrl, state) {
  const scope = [
    "payments.read",
    "payments.write",
    "profiles.read",
    "profiles.write",
  ].join(" ");
  const qs = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUrl,
    response_type: "code",
    scope: scope,
    state: state,
  });
  return `${MOLLIE_OAUTH_AUTHORIZE_URL}?${qs.toString()}`;
}

/**
 * Starts Mollie OAuth connect flow for a BoetePot (admins only).
 */
exports.startMollieConnect = onCall({
  timeoutSeconds: 60,
  secrets: [MOLLIE_CLIENT_ID, MOLLIE_REDIRECT_URL],
}, async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Je bent niet ingelogd.");
    }
    const groupId = String((request.data && request.data.groupId) || "").trim();
    if (!groupId) {
      throw new HttpsError("invalid-argument", "groupId is verplicht.");
    }

    const clientId = requireSecret(MOLLIE_CLIENT_ID, "MOLLIE_CLIENT_ID");
    const redirectUrl = requireSecret(
        MOLLIE_REDIRECT_URL,
        "MOLLIE_REDIRECT_URL",
    );

    const db = admin.firestore();
    const email = request.auth.token && request.auth.token.email ?
      String(request.auth.token.email) :
      "";
    await assertGroupAdmin(db, groupId, request.auth.uid, email);

    const state = crypto.randomBytes(16).toString("hex");
    await db.collection("mollieOAuthStates").doc(state).set({
      groupId: groupId,
      createdByUid: request.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      used: false,
    });

    const url = buildMollieAuthorizeUrl(clientId, redirectUrl, state);
    return {ok: true, url: url};
  } catch (err) {
    logger.error("startMollieConnect failed", {err: String(err)});
    if (err instanceof HttpsError) throw err;
    throw new HttpsError(
        "internal",
        "Mollie koppelen mislukt. Probeer opnieuw.",
    );
  }
});

/**
 * Exchanges an OAuth code for tokens at Mollie.
 *
 * @param {string} code
 * @return {Promise<any>}
 */
async function exchangeMollieCode(code) {
  const clientId = requireSecret(MOLLIE_CLIENT_ID, "MOLLIE_CLIENT_ID");
  const clientSecret = requireSecret(
      MOLLIE_CLIENT_SECRET,
      "MOLLIE_CLIENT_SECRET",
  );
  const redirectUrl = requireSecret(MOLLIE_REDIRECT_URL, "MOLLIE_REDIRECT_URL");

  const body = new URLSearchParams({
    grant_type: "authorization_code",
    code: code,
    redirect_uri: redirectUrl,
    client_id: clientId,
    client_secret: clientSecret,
  });

  const basic = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  const res = await fetch(MOLLIE_OAUTH_TOKEN_URL, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${basic}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: body.toString(),
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`Mollie token exchange failed: ${res.status} ${text}`);
  }
  return JSON.parse(text);
}

/**
 * Refreshes an expired Mollie access token.
 *
 * @param {string} refreshToken
 * @return {Promise<any>}
 */
async function refreshMollieToken(refreshToken) {
  const clientId = requireSecret(MOLLIE_CLIENT_ID, "MOLLIE_CLIENT_ID");
  const clientSecret = requireSecret(
      MOLLIE_CLIENT_SECRET,
      "MOLLIE_CLIENT_SECRET",
  );

  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken,
    client_id: clientId,
    client_secret: clientSecret,
  });
  const basic = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  const res = await fetch(MOLLIE_OAUTH_TOKEN_URL, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${basic}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: body.toString(),
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`Mollie token refresh failed: ${res.status} ${text}`);
  }
  return JSON.parse(text);
}

/**
 * OAuth redirect endpoint (configured in Mollie dashboard).
 *
 * Stores tokens in Firestore (server-side only) and marks the group as
 * connected.
 */
exports.mollieOAuthCallback = onRequest(
    {
      timeoutSeconds: 300,
      secrets: [MOLLIE_CLIENT_ID, MOLLIE_CLIENT_SECRET, MOLLIE_REDIRECT_URL],
    },
    async (req, res) => {
      const code = String(req.query.code || "").trim();
      const state = String(req.query.state || "").trim();
      const error = String(req.query.error || "").trim();
      const errorDescription = String(req.query.error_description || "").trim();

      if (error) {
        res.status(400).send(`Mollie fout: ${error}\n${errorDescription}`);
        return;
      }
      if (!code || !state) {
        res.status(400).send("Ongeldige callback.");
        return;
      }

      const db = admin.firestore();
      const stateRef = db.collection("mollieOAuthStates").doc(state);
      const stateSnap = await stateRef.get();
      if (!stateSnap.exists) {
        res.status(400).send("Ongeldige of verlopen state.");
        return;
      }
      const stateData = stateSnap.data() || {};
      if (stateData.used === true) {
        res.status(409).send("Deze koppeling is al gebruikt.");
        return;
      }
      const groupId = String(stateData.groupId || "").trim();
      if (!groupId) {
        res.status(400).send("State bevat geen groupId.");
        return;
      }

      try {
        await stateRef.set({used: true}, {merge: true});

        const tokens = await exchangeMollieCode(code);
        const accessToken = String(tokens.access_token || "");
        const refreshToken = String(tokens.refresh_token || "");
        const expiresIn = Number(tokens.expires_in || 0);
        const expiresAt = Date.now() + Math.max(0, expiresIn) * 1000;

        let profileId = "";
        try {
          const profiles = await mollieGet(accessToken, "/profiles?limit=1");
          const embedded = profiles && profiles._embedded ?
          profiles._embedded :
          {};
          const items = embedded && embedded.profiles ? embedded.profiles : [];
          if (Array.isArray(items) && items.length > 0 && items[0].id) {
            profileId = String(items[0].id);
          }
        } catch (e) {
          logger.warn(
              "Failed to load Mollie profile id",
              {err: String(e)},
          );
        }

        await db.collection("mollieConnections").doc(groupId).set({
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresAt: expiresAt,
          profileId: profileId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          connectedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        await db.collection("groups").doc(groupId).set({
          mollie: {
            connected: true,
            profileId: profileId || null,
            connectedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        }, {merge: true});

        res
            .status(200)
            .send("Mollie is gekoppeld. Je kunt dit venster sluiten.");
      } catch (e) {
        logger.error(
            "mollieOAuthCallback failed",
            {err: String(e), groupId: groupId},
        );
        res.status(500).send("Koppelen mislukt. Probeer opnieuw.");
      }
    },
);

/**
 * Creates a Mollie checkout for the current user's payment obligation
 * in a payment round (fee is added on top and taken as application fee).
 */
exports.createMolliePaymentForRound = onCall(
    {
      timeoutSeconds: 60,
      secrets: [
        MOLLIE_CLIENT_ID,
        MOLLIE_CLIENT_SECRET,
        MOLLIE_PAYMENT_REDIRECT_URL,
        MOLLIE_WEBHOOK_URL,
      ],
    },
    async (request) => {
      try {
        if (!request.auth) {
          throw new HttpsError("unauthenticated", "Je bent niet ingelogd.");
        }
        const roundId = String(
            (request.data && request.data.roundId) || "",
        ).trim();
        if (!roundId) {
          throw new HttpsError("invalid-argument", "roundId is verplicht.");
        }

        const paymentRedirectUrl = requireSecret(
            MOLLIE_PAYMENT_REDIRECT_URL,
            "MOLLIE_PAYMENT_REDIRECT_URL",
        );
        const webhookUrl = requireSecret(
            MOLLIE_WEBHOOK_URL,
            "MOLLIE_WEBHOOK_URL",
        );

        const db = admin.firestore();
        const roundRef = db.collection("paymentRounds").doc(roundId);
        const roundSnap = await roundRef.get();
        if (!roundSnap.exists) {
          throw new HttpsError("not-found", "Betaalronde bestaat niet (meer).");
        }
        const round = roundSnap.data() || {};
        const groupId = String(round.groupId || "").trim();
        const status = String(round.status || "open").toLowerCase();
        if (!groupId) {
          throw new HttpsError("internal", "Betaalronde mist groupId.");
        }
        if (status !== "open") {
          throw new HttpsError(
              "failed-precondition",
              "Deze betaalronde is gesloten.",
          );
        }

        const groupSnap = await db.collection("groups").doc(groupId).get();
        const g = groupSnap.data() || {};
        const members = Array.isArray(g.members) ? g.members.map(String) : [];
        if (!members.includes(request.auth.uid)) {
          throw new HttpsError(
              "permission-denied",
              "Je zit niet in deze BoetePot.",
          );
        }

        const payRef = roundRef.collection("payments").doc(request.auth.uid);
        const paySnap = await payRef.get();
        if (!paySnap.exists) {
          throw new HttpsError(
              "not-found",
              "Geen betaling gevonden voor jouw account.",
          );
        }
        const pay = paySnap.data() || {};
        if (pay.paid === true) {
          throw new HttpsError(
              "failed-precondition",
              "Deze betaling is al voldaan.",
          );
        }

        const base = Number(pay.amount || 0);
        const baseCents = Math.round(base * 100);
        if (!Number.isFinite(baseCents) || baseCents <= 0) {
          throw new HttpsError(
              "failed-precondition",
              "Je openstaande bedrag is €0.",
          );
        }

        const feeCents = computeFeeCents(baseCents);
        const totalCents = baseCents + feeCents;

        const connRef = db.collection("mollieConnections").doc(groupId);
        const connSnap = await connRef.get();
        const conn = connSnap.data() || {};
        let accessToken = String(conn.accessToken || "");
        let refreshToken = String(conn.refreshToken || "");
        const profileId = String(conn.profileId || "");

        if (!accessToken || !refreshToken) {
          throw new HttpsError(
              "failed-precondition",
              "Mollie is nog niet gekoppeld voor deze BoetePot.",
          );
        }

        const expiresAt = Number(conn.expiresAt || 0);
        if (expiresAt && Date.now() > (expiresAt - 60 * 1000)) {
          const refreshed = await refreshMollieToken(refreshToken);
          accessToken = String(refreshed.access_token || accessToken);
          refreshToken = String(refreshed.refresh_token || refreshToken);
          const expiresIn = Number(refreshed.expires_in || 0);
          const nextExpiresAt = Date.now() + Math.max(0, expiresIn) * 1000;
          await connRef.set({
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: nextExpiresAt,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        }

        const groupName = typeof g.name === "string" && g.name.trim() ?
      g.name.trim() :
      "BoetePot";
        const description = `${groupName} – betaalronde`;

        const body = {
          amount: {currency: "EUR", value: eurValue(totalCents)},
          description: description,
          redirectUrl: paymentRedirectUrl,
          webhookUrl: webhookUrl,
          metadata: {
            groupId: groupId,
            roundId: roundId,
            uid: request.auth.uid,
            baseCents: baseCents,
            feeCents: feeCents,
          },
          applicationFee: {
            amount: {currency: "EUR", value: eurValue(feeCents)},
            description: "BoetePot servicekosten",
          },
        };
        if (profileId) body.profileId = profileId;

        const created = await molliePost(accessToken, "/payments", body);
        const paymentId = String(created.id || "");
        const checkoutUrl = created &&
      created._links &&
      created._links.checkout &&
      created._links.checkout.href ?
      String(created._links.checkout.href) :
      "";
        if (!paymentId || !checkoutUrl) {
          throw new Error("Mollie response mist id/checkoutUrl");
        }

        await db.collection("molliePayments").doc(paymentId).set({
          groupId: groupId,
          roundId: roundId,
          uid: request.auth.uid,
          baseCents: baseCents,
          feeCents: feeCents,
          totalCents: totalCents,
          status: String(created.status || "open"),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        await payRef.set({
          molliePaymentId: paymentId,
          mollieStatus: String(created.status || "open"),
          mollieTotalCents: totalCents,
          mollieFeeCents: feeCents,
        }, {merge: true});

        return {ok: true, checkoutUrl: checkoutUrl};
      } catch (err) {
        logger.error("createMolliePaymentForRound failed", {err: String(err)});
        if (err instanceof HttpsError) throw err;
        throw new HttpsError(
            "internal",
            "Betaling starten mislukt. Probeer opnieuw.",
        );
      }
    },
);

/**
 * Mollie webhook endpoint.
 * Mollie sends the payment id, we verify by fetching payment status.
 */
exports.mollieWebhook = onRequest({
  timeoutSeconds: 300,
  secrets: [MOLLIE_CLIENT_ID, MOLLIE_CLIENT_SECRET],
}, async (req, res) => {
  try {
    let id = "";
    if (req.query && req.query.id) {
      id = String(req.query.id).trim();
    }
    if (!id && req.body && typeof req.body === "object") {
      id = String(req.body.id || "").trim();
    }
    if (!id && typeof req.body === "string") {
      const params = new URLSearchParams(req.body);
      id = String(params.get("id") || "").trim();
    }
    if (!id) {
      res.status(200).send("no-id");
      return;
    }

    const db = admin.firestore();
    const payMetaSnap = await db.collection("molliePayments").doc(id).get();
    if (!payMetaSnap.exists) {
      res.status(200).send("unknown");
      return;
    }
    const meta = payMetaSnap.data() || {};
    const groupId = String(meta.groupId || "").trim();
    const roundId = String(meta.roundId || "").trim();
    const uid = String(meta.uid || "").trim();
    if (!groupId || !roundId || !uid) {
      res.status(200).send("bad-meta");
      return;
    }

    const connRef = db.collection("mollieConnections").doc(groupId);
    const connSnap = await connRef.get();
    const conn = connSnap.data() || {};
    let accessToken = String(conn.accessToken || "");
    let refreshToken = String(conn.refreshToken || "");
    if (!accessToken || !refreshToken) {
      res.status(200).send("no-conn");
      return;
    }

    const expiresAt = Number(conn.expiresAt || 0);
    if (expiresAt && Date.now() > (expiresAt - 60 * 1000)) {
      const refreshed = await refreshMollieToken(refreshToken);
      accessToken = String(refreshed.access_token || accessToken);
      refreshToken = String(refreshed.refresh_token || refreshToken);
      const expiresIn = Number(refreshed.expires_in || 0);
      const nextExpiresAt = Date.now() + Math.max(0, expiresIn) * 1000;
      await connRef.set({
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: nextExpiresAt,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    const payment = await mollieGet(accessToken, `/payments/${id}`);
    const status = String(payment.status || "").toLowerCase();

    await payMetaSnap.ref.set({
      status: status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    const roundPayRef = db
        .collection("paymentRounds")
        .doc(roundId)
        .collection("payments")
        .doc(uid);

    await roundPayRef.set({
      mollieStatus: status,
      molliePaymentId: id,
    }, {merge: true});

    if (status === "paid") {
      await roundPayRef.set({
        paid: true,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        markedByUid: "mollie",
      }, {merge: true});
    }

    res.status(200).send("ok");
  } catch (e) {
    logger.error("mollieWebhook failed", {err: String(e)});
    res.status(200).send("error");
  }
});
