const admin = require("firebase-admin");
const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");

admin.initializeApp();

// Keep the function in the same region as Firestore/Eventarc.
setGlobalOptions({maxInstances: 10, region: "europe-west2"});

const PAYMENT_ROUND_PATH = "paymentRounds/{roundId}";
const BOETE_PATH = "boetes/{boeteId}";

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
