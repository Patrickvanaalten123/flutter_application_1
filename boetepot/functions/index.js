const admin = require("firebase-admin");
const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

admin.initializeApp();

// Keep the function in the same region as Firestore/Eventarc.
setGlobalOptions({maxInstances: 10, region: "europe-west2"});

const PAYMENT_ROUND_PATH = "paymentRounds/{roundId}";
const BOETE_PATH = "boetes/{boeteId}";

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
 * Deletes the currently authenticated user's account and personal data.
 *
 * - Removes the user from all groups.
 * - Deletes `users/{uid}` and `userGroups/{uid}/groups/*`.
 * - Deletes profile photo `userphotos/{uid}.jpg` (best-effort).
 * - Removes the user's payment obligation docs from
 *   `paymentRounds/{roundId}/payments/{uid}` (best-effort).
 * - Anonymizes email fields in historical docs (best-effort).
 * - Deletes the Firebase Auth user.
 */
exports.deleteMyAccount = onCall({timeoutSeconds: 540}, async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Je bent niet ingelogd.");
    }

    const uid = String(request.auth.uid);
    const db = admin.firestore();

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
    const groupIdList = Array.from(groupIds);
    for (let i = 0; i < groupIdList.length; i += 10) {
      const chunk = groupIdList.slice(i, i + 10);
      const roundsSnap = await db
          .collection("paymentRounds")
          .where("groupId", "in", chunk)
          .get();
      for (const roundDoc of roundsSnap.docs) {
        await roundDoc.ref
            .collection("payments")
            .doc(uid)
            .delete()
            .catch(() => null);
      }
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
    return {ok: true};
  } catch (err) {
    logger.error("deleteMyAccount failed", {err: String(err)});
    if (err instanceof HttpsError) throw err;
    throw new HttpsError(
        "internal",
        "Account verwijderen mislukt. Probeer opnieuw.",
    );
  }
});
