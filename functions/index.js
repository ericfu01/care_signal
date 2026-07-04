const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const crypto = require('crypto');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getAuth } = require('firebase-admin/auth');
const { getStorage } = require('firebase-admin/storage');
const {
  sendAppEmail,
  peerGroupFamilyInviteEmail,
  peerGroupCoHostInviteEmail,
} = require('./email');

initializeApp();

const ONLINE_WINDOW_MS = 3 * 60 * 1000;

function defaultDurationMinutes(serviceType) {
  switch (serviceType) {
    case 'respite':
      return 120;
    case 'meal':
      return 60;
    case 'transport':
      return 90;
    case 'peer':
      return 60;
    default:
      return 60;
  }
}

function requestDurationMinutes(data) {
  const minutes = data.durationMinutes;
  if (typeof minutes === 'number' && minutes > 0) return minutes;
  return defaultDurationMinutes(data.serviceType || '');
}

function requestBlockStartMs(data, nowMs) {
  if (data.needsNow === true) return nowMs;
  const scheduled = data.scheduledAt;
  if (scheduled && typeof scheduled.toMillis === 'function') {
    return scheduled.toMillis();
  }
  return nowMs;
}

function blockForRequest(requestData, requestId, familyUserId, nowMs) {
  const startMs = requestBlockStartMs(requestData, nowMs);
  const durationMs = requestDurationMinutes(requestData) * 60 * 1000;
  return {
    startAt: Timestamp.fromMillis(startMs),
    endAt: Timestamp.fromMillis(startMs + durationMs),
    requestId,
    familyUserId,
  };
}

function parseSchedule(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.filter(
    (slot) =>
      typeof slot.weekday === 'number' &&
      typeof slot.startMinutes === 'number' &&
      typeof slot.endMinutes === 'number' &&
      slot.endMinutes > slot.startMinutes,
  );
}

function dartWeekday(date) {
  const day = date.getDay();
  return day === 0 ? 7 : day;
}

function isAvailableAt(slots, date) {
  if (slots.length === 0) return false;
  const weekday = dartWeekday(date);
  const minutes = date.getHours() * 60 + date.getMinutes();
  return slots.some(
    (slot) =>
      slot.weekday === weekday &&
      minutes >= slot.startMinutes &&
      minutes < slot.endMinutes,
  );
}

function parseBlocks(raw, nowMs) {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((item) => {
      if (!item || !item.startAt || !item.endAt) return null;
      const startAt =
        item.startAt instanceof Timestamp ? item.startAt : Timestamp.fromDate(new Date(item.startAt));
      const endAt =
        item.endAt instanceof Timestamp ? item.endAt : Timestamp.fromDate(new Date(item.endAt));
      if (endAt.toMillis() <= startAt.toMillis()) return null;
      if (endAt.toMillis() <= nowMs) return null;
      return {
        startAt,
        endAt,
        requestId: item.requestId || null,
        familyUserId: item.familyUserId || null,
      };
    })
    .filter(Boolean)
    .sort((a, b) => a.startAt.toMillis() - b.startAt.toMillis());
}

function isBlockedAt(blocks, nowMs) {
  return blocks.some((block) => {
    const start = block.startAt.toMillis();
    const end = block.endAt.toMillis();
    return nowMs >= start && nowMs < end;
  });
}

function blocksToFirestore(blocks) {
  return blocks.map((block) => ({
    startAt: block.startAt,
    endAt: block.endAt,
    ...(block.requestId ? { requestId: block.requestId } : {}),
    ...(block.familyUserId ? { familyUserId: block.familyUserId } : {}),
  }));
}

async function updateVolunteerAvailabilityBlocks(db, volunteerUid, nextBlocks) {
  if (!volunteerUid) return;

  const volunteerRef = db.collection('users').doc(volunteerUid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(volunteerRef);
    if (!snap.exists) return;

    const data = snap.data() || {};
    const nowMs = Date.now();
    const slots = parseSchedule(
      data.volunteerAvailabilitySchedule || data.volunteerAvailability,
    );
    const online =
      isAvailableAt(slots, new Date(nowMs)) && !isBlockedAt(nextBlocks, nowMs);

    tx.set(
      volunteerRef,
      {
        volunteerAvailabilityBlocks: blocksToFirestore(nextBlocks),
        volunteerOnline: online,
      },
      { merge: true },
    );
  });
}

async function addBlockForAcceptedRequest(
  db,
  volunteerUid,
  familyUserId,
  requestId,
  requestData,
) {
  const nowMs = Date.now();
  const block =
    requestData.blockedStartAt && requestData.blockedEndAt
      ? {
          startAt: requestData.blockedStartAt,
          endAt: requestData.blockedEndAt,
          requestId,
          familyUserId,
        }
      : blockForRequest(requestData, requestId, familyUserId, nowMs);

  const volunteerRef = db.collection('users').doc(volunteerUid);
  const snap = await volunteerRef.get();
  if (!snap.exists) return;

  const existing = parseBlocks(
    (snap.data() || {}).volunteerAvailabilityBlocks,
    nowMs,
  ).filter((item) => item.requestId !== requestId);
  existing.push(block);
  existing.sort((a, b) => a.startAt.toMillis() - b.startAt.toMillis());

  await updateVolunteerAvailabilityBlocks(db, volunteerUid, existing);
}

async function removeBlockForRequest(db, volunteerUid, requestId) {
  const volunteerRef = db.collection('users').doc(volunteerUid);
  const snap = await volunteerRef.get();
  if (!snap.exists) return;

  const nowMs = Date.now();
  const next = parseBlocks(
    (snap.data() || {}).volunteerAvailabilityBlocks,
    nowMs,
  ).filter((item) => item.requestId !== requestId);

  await updateVolunteerAvailabilityBlocks(db, volunteerUid, next);
}

function serviceTypeLabel(serviceType, followUpOnly) {
  switch (serviceType) {
    case 'respite':
      return 'Respite care';
    case 'meal':
      return 'Meal delivery';
    case 'transport':
      return followUpOnly ? 'Transportation follow-up' : 'Transportation';
    case 'peer':
      return 'Peer support';
    default:
      return 'Support visit';
  }
}

async function shouldSkipPush(db, recipientUid) {
  const userSnap = await db.collection('users').doc(recipientUid).get();
  if (!userSnap.exists) return false;
  const lastActive = userSnap.data().lastActiveAt;
  if (lastActive && lastActive.toMillis() > Date.now() - ONLINE_WINDOW_MS) {
    return true;
  }
  return false;
}

async function loadFcmTokens(db, recipientUid) {
  const tokensSnap = await db
    .collection('users')
    .doc(recipientUid)
    .collection('fcm_tokens')
    .get();

  return tokensSnap.docs
    .map((doc) => doc.data().token)
    .filter((t) => typeof t === 'string' && t.length > 0);
}

async function writeInAppNotification(db, recipientUid, notifId, payload) {
  await db
    .collection('users')
    .doc(recipientUid)
    .collection('notifications')
    .doc(notifId)
    .set(
      {
        ...payload,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

async function sendPushToUser(db, recipientUid, { title, body, data, androidChannelId }) {
  if (await shouldSkipPush(db, recipientUid)) return;

  const tokensSnap = await db
    .collection('users')
    .doc(recipientUid)
    .collection('fcm_tokens')
    .get();

  const tokens = tokensSnap.docs
    .map((doc) => doc.data().token)
    .filter((t) => typeof t === 'string' && t.length > 0);

  if (tokens.length === 0) return;

  const tokenDocByValue = new Map();
  for (const doc of tokensSnap.docs) {
    const token = doc.data().token;
    if (typeof token === 'string' && token.length > 0) {
      tokenDocByValue.set(token, doc.ref);
    }
  }

  try {
    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data,
      android: {
        priority: 'high',
        notification: { channelId: androidChannelId },
      },
      apns: {
        payload: { aps: { sound: 'default' } },
      },
    });

    if (response.failureCount > 0) {
      const staleDeletes = [];
      response.responses.forEach((result, index) => {
        if (result.success) return;
        const code = result.error?.code || '';
        if (
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/registration-token-not-registered'
        ) {
          const ref = tokenDocByValue.get(tokens[index]);
          if (ref) staleDeletes.push(ref);
        }
      });
      if (staleDeletes.length > 0) {
        const batch = db.batch();
        staleDeletes.forEach((ref) => batch.delete(ref));
        await batch.commit();
      }
    }
  } catch (err) {
    console.error('FCM send failed', recipientUid, err);
  }
}

async function loadLaneVolunteerUids(db, catalogId) {
  const snap = await db
    .collection('users')
    .where('accountType', '==', 'volunteer')
    .where('volunteerCatalogId', '==', catalogId)
    .where('backgroundCheckStatus', '==', 'approved')
    .limit(30)
    .get();
  return snap.docs.map((doc) => doc.id);
}

function requestWhenLabel(data) {
  if (data.needsNow === true) return 'ASAP';
  const scheduled = data.scheduledAt;
  if (scheduled && typeof scheduled.toDate === 'function') {
    return scheduled.toDate().toLocaleString('en-US', {
      weekday: 'short',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    });
  }
  return 'Scheduled';
}

function buildNewRequestNotification(data, familyName) {
  const service = serviceTypeLabel(data.serviceType, data.followUpOnly === true);
  const when = requestWhenLabel(data);
  const urgent = data.priority === 'urgent';
  const title = urgent
    ? `URGENT: ${service} request`
    : `New ${service} request`;
  const body = `${familyName} · ${when}`;
  return { title, body, urgent };
}

function resolveNewRequestRecipients(data, laneVolunteerUids) {
  if (data.priority === 'urgent') return laneVolunteerUids;
  if (data.volunteerUid) return [data.volunteerUid];
  return laneVolunteerUids;
}

async function notifyVolunteersOfNewRequest(db, familyUserId, requestId, data) {
  if (data.status !== 'pending') return;

  const catalogId = data.volunteerId;
  if (!catalogId) return;

  let familyName = (data.familyDisplayName || '').trim();
  if (!familyName) {
    const familySnap = await db.collection('users').doc(familyUserId).get();
    familyName = (familySnap.data()?.displayName || 'A family').trim();
  }

  const laneUids = await loadLaneVolunteerUids(db, catalogId);
  if (laneUids.length === 0) return;

  const recipients = [
    ...new Set(resolveNewRequestRecipients(data, laneUids).filter(Boolean)),
  ];
  if (recipients.length === 0) return;

  const { title, body, urgent } = buildNewRequestNotification(data, familyName);
  const notifId = `${requestId}_new`;

  for (const volunteerUid of recipients) {
    await writeInAppNotification(db, volunteerUid, notifId, {
      type: 'volunteer_request_new',
      title,
      body,
      familyUserId,
      requestId,
      otherUid: familyUserId,
      otherDisplayName: familyName,
      urgent,
    });

    await sendPushToUser(db, volunteerUid, {
      title,
      body,
      androidChannelId: 'volunteer_requests',
      data: {
        type: 'volunteer_request_new',
        familyUserId,
        requestId,
        otherUid: familyUserId,
        otherDisplayName: familyName,
        urgent: urgent ? 'true' : 'false',
      },
    });
  }
}

/**
 * When a family DM is sent, write an in-app notification and send FCM
 * to the other participant (unless they were active in the app recently).
 */
exports.notifyFamilyMessage = onDocumentCreated(
  {
    document: 'families/{familyId}/family_chats/{chatId}/messages/{messageId}',
    region: 'us-central1',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const { familyId, chatId, messageId } = event.params;
    const data = snap.data();
    const senderUid = data.senderUid;
    const senderName = (data.senderName || 'Family member').trim();
    const text = String(data.text || '').trim().slice(0, 200);

    if (!senderUid || !text) return;

    const db = getFirestore();
    const chatRef = db.doc(`families/${familyId}/family_chats/${chatId}`);
    const chatSnap = await chatRef.get();
    if (!chatSnap.exists) return;

    const chat = chatSnap.data();
    const participants = chat.participantUids || [];
    const recipients = participants.filter((uid) => uid !== senderUid);
    if (recipients.length === 0) return;

    const title = `Message from ${senderName}`;
    const body = text;

    for (const recipientUid of recipients) {
      await writeInAppNotification(db, recipientUid, messageId, {
        type: 'family_message',
        title,
        body,
        familyId,
        chatId,
        otherUid: senderUid,
        otherDisplayName: senderName,
      });

      await sendPushToUser(db, recipientUid, {
        title,
        body,
        androidChannelId: 'family_messages',
        data: {
          type: 'family_message',
          familyId,
          chatId,
          otherUid: senderUid,
          otherDisplayName: senderName,
        },
      });
    }
  },
);

/**
 * Notify lane volunteers when a family submits a new support request.
 */
exports.notifyVolunteerNewRequest = onDocumentCreated(
  {
    document: 'users/{familyUserId}/volunteer_requests/{requestId}',
    region: 'us-central1',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const { familyUserId, requestId } = event.params;
    await notifyVolunteersOfNewRequest(
      getFirestore(),
      familyUserId,
      requestId,
      snap.data(),
    );
  },
);

/**
 * Re-notify when a counter-proposed request goes back to pending.
 */
exports.notifyVolunteerRequestReopened = onDocumentUpdated(
  {
    document: 'users/{familyUserId}/volunteer_requests/{requestId}',
    region: 'us-central1',
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== 'pending') return;
    if (before.status !== 'counter_proposed') return;

    const { familyUserId, requestId } = event.params;
    await notifyVolunteersOfNewRequest(
      getFirestore(),
      familyUserId,
      requestId,
      after,
    );
  },
);

/**
 * When a family cancels a volunteer request, notify assigned volunteers.
 */
exports.notifyVolunteerRequestCancelled = onDocumentUpdated(
  {
    document: 'users/{familyUserId}/volunteer_requests/{requestId}',
    region: 'us-central1',
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== 'cancelled') return;

    const { familyUserId, requestId } = event.params;
    const db = getFirestore();

    const volunteerUids = new Set();
    if (before.volunteerUid) volunteerUids.add(before.volunteerUid);
    if (before.counterVolunteerUid) volunteerUids.add(before.counterVolunteerUid);
    if (volunteerUids.size === 0) return;

    const familySnap = await db.collection('users').doc(familyUserId).get();
    const familyName = (familySnap.data()?.displayName || 'A family').trim();
    const serviceLabel = serviceTypeLabel(
      after.serviceType || before.serviceType,
      after.followUpOnly === true || before.followUpOnly === true,
    );

    const wasAccepted = before.status === 'accepted';
    const title = wasAccepted ? 'Visit cancelled' : 'Request cancelled';
    const body = wasAccepted
      ? `${familyName} cancelled their confirmed ${serviceLabel.toLowerCase()} visit.`
      : `${familyName} cancelled a ${serviceLabel.toLowerCase()} request you were involved with.`;

    const notifId = `${requestId}_cancelled`;

    for (const volunteerUid of volunteerUids) {
      await writeInAppNotification(db, volunteerUid, notifId, {
        type: 'volunteer_request_cancelled',
        title,
        body,
        familyUserId,
        requestId,
        otherUid: familyUserId,
        otherDisplayName: familyName,
      });

      await sendPushToUser(db, volunteerUid, {
        title,
        body,
        androidChannelId: 'volunteer_requests',
        data: {
          type: 'volunteer_request_cancelled',
          familyUserId,
          requestId,
          otherUid: familyUserId,
          otherDisplayName: familyName,
        },
      });
    }
  },
);

/**
 * Instantly sync volunteer calendar blocks when a request is accepted,
 * and remove blocks when cancelled or completed (including family counter accept).
 */
exports.syncVolunteerAvailabilityOnRequestChange = onDocumentUpdated(
  {
    document: 'users/{familyUserId}/volunteer_requests/{requestId}',
    region: 'us-central1',
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;

    const beforeStatus = before.status;
    const afterStatus = after.status;
    if (beforeStatus === afterStatus) return;

    const { familyUserId, requestId } = event.params;
    const db = getFirestore();

    if (afterStatus === 'accepted') {
      const volunteerUid = after.volunteerUid;
      if (!volunteerUid) return;
      await addBlockForAcceptedRequest(
        db,
        volunteerUid,
        familyUserId,
        requestId,
        after,
      );
      return;
    }

    if (afterStatus === 'cancelled' || afterStatus === 'completed') {
      const volunteerUid = after.volunteerUid || before.volunteerUid;
      if (!volunteerUid) return;
      await removeBlockForRequest(db, volunteerUid, requestId);
    }
  },
);

function counterWhenLabel(data) {
  const counter = data.counterScheduledAt;
  if (counter && typeof counter.toDate === 'function') {
    return counter.toDate().toLocaleString('en-US', {
      weekday: 'short',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    });
  }
  return 'a new time';
}

/**
 * Notify the family when a volunteer accepts, proposes a counter time, or completes a visit.
 */
exports.notifyFamilyVolunteerRequestUpdate = onDocumentUpdated(
  {
    document: 'users/{familyUserId}/volunteer_requests/{requestId}',
    region: 'us-central1',
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;

    const { familyUserId, requestId } = event.params;
    const db = getFirestore();

    const serviceLabel = serviceTypeLabel(
      after.serviceType || before.serviceType,
      after.followUpOnly === true || before.followUpOnly === true,
    ).toLowerCase();
    const volunteerName = (
      after.volunteerName ||
      before.volunteerName ||
      after.counterVolunteerName ||
      before.counterVolunteerName ||
      'A volunteer'
    ).trim();
    const volunteerUid =
      after.volunteerUid ||
      before.volunteerUid ||
      after.counterVolunteerUid ||
      before.counterVolunteerUid ||
      '';

    let type;
    let title;
    let body;

    if (after.status === 'counter_proposed' && before.status !== 'counter_proposed') {
      type = 'family_request_counter';
      title = 'Alternate time proposed';
      body = `${volunteerName} suggested ${counterWhenLabel(after)} for your ${serviceLabel} request.`;
    } else if (after.status === 'accepted' && before.status !== 'counter_proposed') {
      type = 'family_request_accepted';
      title = 'Visit confirmed';
      body = `${volunteerName} accepted your ${serviceLabel} request · ${requestWhenLabel(after)}`;
    } else if (after.status === 'completed' && before.status !== 'completed') {
      type = 'family_request_completed';
      title = 'Visit completed';
      body = `${volunteerName} marked your ${serviceLabel} visit as complete.`;
    } else if (after.status === 'declined' && before.status !== 'declined') {
      type = 'family_request_declined';
      title = 'Request declined';
      body = `${volunteerName} is unable to take your ${serviceLabel} request right now.`;
    } else {
      return;
    }

    const notifId = `${requestId}_${type}`;

    await writeInAppNotification(db, familyUserId, notifId, {
      type,
      title,
      body,
      requestId,
      familyUserId,
      otherUid: volunteerUid,
      otherDisplayName: volunteerName,
    });

    await sendPushToUser(db, familyUserId, {
      title,
      body,
      androidChannelId: 'family_messages',
      data: {
        type,
        requestId,
        familyUserId,
        otherUid: volunteerUid,
        otherDisplayName: volunteerName,
      },
    });
  },
);

const RISK_SCORE_THRESHOLD = 55;

/**
 * Notify family members when someone submits a low wellness check-in.
 * Respects each recipient's `riskAlertsEnabled` preference (default on).
 */
exports.notifyFamilyRiskAlert = onDocumentCreated(
  {
    document: 'users/{userId}/daily_check_ins/{checkInId}',
    region: 'us-central1',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const score = data.score;
    if (typeof score !== 'number' || score >= RISK_SCORE_THRESHOLD) return;

    const { userId, checkInId } = event.params;
    const db = getFirestore();

    const memberSnap = await db.collection('users').doc(userId).get();
    if (!memberSnap.exists) return;

    const memberData = memberSnap.data() || {};
    const familyId = memberData.familyId;
    if (!familyId || typeof familyId !== 'string') return;

    const memberName = (
      data.memberName ||
      memberData.displayName ||
      'A family member'
    ).trim();
    const dayKey =
      typeof data.dayKey === 'string' && data.dayKey.length > 0
        ? data.dayKey
        : checkInId;

    const title = 'Wellness check-in alert';
    const body = `${memberName} reported a low wellness score (${score}). They may need extra support today.`;
    const notifId = `${userId}_${dayKey}_risk`;

    const familySnap = await db
      .collection('users')
      .where('familyId', '==', familyId)
      .limit(25)
      .get();

    for (const recipientDoc of familySnap.docs) {
      if (recipientDoc.id === userId) continue;

      const recipient = recipientDoc.data();
      if (recipient.riskAlertsEnabled === false) continue;

      await writeInAppNotification(db, recipientDoc.id, notifId, {
        type: 'family_risk_alert',
        title,
        body,
        otherUid: userId,
        otherDisplayName: memberName,
        score: String(score),
      });

      await sendPushToUser(db, recipientDoc.id, {
        title,
        body,
        androidChannelId: 'family_messages',
        data: {
          type: 'family_risk_alert',
          otherUid: userId,
          otherDisplayName: memberName,
          score: String(score),
        },
      });
    }
  },
);

/**
 * One-time bootstrap: seeds config/transport_coverage.
 * Call once after deploy. GET/POST ?secret=care-signal-bootstrap
 */
exports.seedTransportCoverage = onRequest(
  { region: 'us-central1' },
  async (req, res) => {
    if (req.method !== 'GET' && req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    const expected = process.env.SEED_SECRET || 'care-signal-bootstrap';
    if (req.query.secret !== expected) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const db = getFirestore();
    const ref = db.doc('config/transport_coverage');
    await ref.set(
      {
        regionName: 'San Francisco Bay Area',
        zipPrefixes: ['940', '941', '943', '944', '945', '950', '951'],
        zipCodes: [],
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const snap = await ref.get();
    res.json({ ok: true, path: ref.path, data: snap.data() });
  },
);

function volunteerAgeYears(birthDate, onDate) {
  let years = onDate.getFullYear() - birthDate.getFullYear();
  const birthdayThisYear = new Date(
    onDate.getFullYear(),
    birthDate.getMonth(),
    birthDate.getDate(),
  );
  if (onDate < birthdayThisYear) years -= 1;
  return years;
}

/**
 * When a volunteer submits a background check, validate the application and
 * approve volunteers who meet basic requirements (pilot screening).
 */
exports.processVolunteerBackgroundCheck = onDocumentUpdated(
  { document: 'users/{userId}', region: 'us-central1' },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!after || after.accountType !== 'volunteer') return;
    if (before?.backgroundCheckStatus === after.backgroundCheckStatus) return;
    if (after.backgroundCheckStatus !== 'pending') return;

    const userId = event.params.userId;
    const db = getFirestore();
    const userRef = db.collection('users').doc(userId);

    const appSnap = await userRef
      .collection('background_check_application')
      .doc('current')
      .get();

    if (!appSnap.exists) {
      await userRef.set(
        {
          backgroundCheckStatus: 'rejected',
          backgroundCheckNote:
            'We could not find your screening application. Please submit again.',
          backgroundCheckReviewedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return;
    }

    const app = appSnap.data() || {};
    const first = (app.legalFirstName || '').trim();
    const last = (app.legalLastName || '').trim();
    const street = (app.streetAddress || '').trim();
    const city = (app.city || '').trim();
    const state = (app.state || '').trim();
    const zip = (app.zip || '').trim();
    const dob = app.dateOfBirth;

    let rejectNote = '';
    if (!first || !last || !street || !city || !state || zip.length < 5) {
      rejectNote = 'Some required information was missing. Please review and resubmit.';
    } else if (!dob || typeof dob.toDate !== 'function') {
      rejectNote = 'A valid date of birth is required.';
    } else {
      const birthDate = dob.toDate();
      const age = volunteerAgeYears(birthDate, new Date());
      if (age < 18) {
        rejectNote = 'Volunteers must be at least 18 years old.';
      }
    }

    if (rejectNote) {
      await userRef.set(
        {
          backgroundCheckStatus: 'rejected',
          backgroundCheckNote: rejectNote,
          backgroundCheckReviewedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return;
    }

    await writeInAppNotification(db, userId, 'background_check_pending', {
      type: 'volunteer_background_check_pending',
      title: 'Screening submitted',
      body: 'Our team will review your volunteer screening shortly.',
    });
  },
);

/**
 * Notify volunteers when staff approves or rejects their background check.
 */
exports.notifyVolunteerBackgroundCheckReviewed = onDocumentUpdated(
  { document: 'users/{userId}', region: 'us-central1' },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!after || after.accountType !== 'volunteer') return;
    if (before?.backgroundCheckStatus === after.backgroundCheckStatus) return;

    const status = after.backgroundCheckStatus;
    if (status !== 'approved' && status !== 'rejected') return;
    if (before?.backgroundCheckStatus !== 'pending') return;

    const userId = event.params.userId;
    const db = getFirestore();

    if (status === 'approved') {
      await writeInAppNotification(db, userId, 'background_check_approved', {
        type: 'volunteer_background_check_approved',
        title: 'Background check approved',
        body: 'You can finish volunteer setup and start helping families.',
      });
      await sendPushToUser(db, userId, {
        title: 'Background check approved',
        body: 'You can finish volunteer setup and start helping families.',
        androidChannelId: 'volunteer_requests',
        data: { type: 'volunteer_background_check_approved' },
      });
      return;
    }

    const note =
      (after.backgroundCheckNote || 'Please review your screening and try again.').trim();
    await writeInAppNotification(db, userId, 'background_check_rejected', {
      type: 'volunteer_background_check_rejected',
      title: 'Screening needs attention',
      body: note,
    });
    await sendPushToUser(db, userId, {
      title: 'Screening needs attention',
      body: note,
      androidChannelId: 'volunteer_requests',
      data: { type: 'volunteer_background_check_rejected' },
    });
  },
);

async function peerGroupManagerUids(db, groupId) {
  const groupSnap = await db.collection('peer_groups').doc(groupId).get();
  if (!groupSnap.exists) return [];
  const data = groupSnap.data() || {};
  const uids = new Set();
  if (data.hostUid) uids.add(data.hostUid);
  const cohosts = data.cohostUids || [];
  for (const uid of cohosts) {
    if (uid) uids.add(uid);
  }
  return [...uids];
}

/**
 * Notify peer group hosts when a family requests to join.
 */
exports.notifyPeerGroupJoinRequest = onDocumentCreated(
  {
    document: 'peer_groups/{groupId}/join_requests/{requesterUid}',
    region: 'us-central1',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    if ((data.status || 'pending') !== 'pending') return;

    const { groupId, requesterUid } = event.params;
    const db = getFirestore();
    const managers = await peerGroupManagerUids(db, groupId);
    const requesterName = (data.requesterName || 'A family member').trim();
    const groupTitle = (data.groupTitle || 'your peer group').trim();

    for (const managerUid of managers) {
      if (managerUid === requesterUid) continue;
      const notifId = `peer_join_${groupId}_${requesterUid}`;
      await writeInAppNotification(db, managerUid, notifId, {
        type: 'peer_group_join_request',
        title: 'New peer group request',
        body: `${requesterName} asked to join ${groupTitle}.`,
        groupId,
        requesterUid,
      });
      await sendPushToUser(db, managerUid, {
        title: 'New peer group request',
        body: `${requesterName} asked to join ${groupTitle}.`,
        androidChannelId: 'volunteer_requests',
        data: {
          type: 'peer_group_join_request',
          groupId,
          requesterUid,
        },
      });
    }
  },
);

/**
 * Notify a volunteer when invited to co-host a peer group.
 */
exports.notifyPeerGroupCoHostInvite = onDocumentCreated(
  {
    document: 'users/{inviteeUid}/peer_group_cohost_invites/{groupId}',
    region: 'us-central1',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    if ((data.status || 'pending') !== 'pending') return;

    const { inviteeUid, groupId } = event.params;
    const db = getFirestore();
    const hostName = (data.hostName || 'A host').trim();
    const groupTitle = (data.groupTitle || 'a peer group').trim();
    const inviteeEmail = (data.inviteeEmail || '').trim().toLowerCase();

    await writeInAppNotification(db, inviteeUid, `peer_cohost_${groupId}`, {
      type: 'peer_group_cohost_invite',
      title: 'Co-host invitation',
      body: `${hostName} invited you to co-host ${groupTitle}.`,
      groupId,
    });
    await sendPushToUser(db, inviteeUid, {
      title: 'Co-host invitation',
      body: `${hostName} invited you to co-host ${groupTitle}.`,
      androidChannelId: 'volunteer_requests',
      data: {
        type: 'peer_group_cohost_invite',
        groupId,
      },
    });

    if (inviteeEmail) {
      const helpUrl = await loadInviteHelpUrl(db);
      const mail = peerGroupCoHostInviteEmail({
        hostName,
        groupTitle,
        inviteeEmail,
        helpUrl,
      });
      const emailConfig = await loadEmailConfig(db);
      await sendAppEmail({
        apiKey: emailConfig.apiKey,
        from: emailConfig.from,
        to: inviteeEmail,
        subject: mail.subject,
        text: mail.text,
      });
    }
  },
);

/**
 * Notify a family member when invited to a peer group (in-app + push if account exists).
 */
exports.notifyPeerGroupFamilyInvite = onDocumentCreated(
  {
    document: 'peer_groups/{groupId}/invitations/{invitationId}',
    region: 'us-central1',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    if ((data.status || 'pending') !== 'pending') return;

    const { groupId, invitationId } = event.params;
    const db = getFirestore();
    const inviteeEmail = (data.inviteeEmail || '').trim().toLowerCase();
    let inviteeUid = (data.inviteeUid || '').trim();
    if (!inviteeUid && invitationId.includes('@')) {
      inviteeUid = await findUserUidByEmail(db, invitationId);
    }
    if (!inviteeUid && inviteeEmail) {
      inviteeUid = await findUserUidByEmail(db, inviteeEmail);
    }

    const groupTitle = (data.groupTitle || 'a peer group').trim();
    const hostUid = (data.hostUid || '').trim();
    let hostName = 'A host';
    if (hostUid) {
      const hostSnap = await db.collection('users').doc(hostUid).get();
      hostName = (hostSnap.data()?.displayName || hostName).trim();
    }

    if (inviteeEmail) {
      const helpUrl = await loadInviteHelpUrl(db);
      const mail = peerGroupFamilyInviteEmail({
        hostName,
        groupTitle,
        inviteeEmail,
        helpUrl,
      });
      const emailConfig = await loadEmailConfig(db);
      await sendAppEmail({
        apiKey: emailConfig.apiKey,
        from: emailConfig.from,
        to: inviteeEmail,
        subject: mail.subject,
        text: mail.text,
      });
    }

    if (!inviteeUid) return;

    await db
      .collection('users')
      .doc(inviteeUid)
      .collection('peer_group_invitations')
      .doc(groupId)
      .set({
        groupId,
        groupTitle,
        hostUid,
        hostName,
        inviteeEmail,
        status: 'pending',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

    const notifId = `peer_family_invite_${groupId}`;
    await writeInAppNotification(db, inviteeUid, notifId, {
      type: 'peer_group_family_invite',
      title: 'Peer group invitation',
      body: `${hostName} invited you to join ${groupTitle}.`,
      groupId,
    });
    await sendPushToUser(db, inviteeUid, {
      title: 'Peer group invitation',
      body: `${hostName} invited you to join ${groupTitle}.`,
      androidChannelId: 'volunteer_requests',
      data: {
        type: 'peer_group_family_invite',
        groupId,
      },
    });
  },
);

async function loadInviteHelpUrl(db) {
  try {
    const snap = await db.doc('config/app').get();
    const url = (snap.data()?.inviteHelpUrl || '').trim();
    return url || null;
  } catch (_) {
    return null;
  }
}

async function loadEmailConfig(db) {
  try {
    const snap = await db.doc('config/email').get();
    const data = snap.data() || {};
    return {
      apiKey: (data.sendgridApiKey || '').trim(),
      from: (data.emailFrom || '').trim(),
    };
  } catch (_) {
    return { apiKey: '', from: '' };
  }
}

async function assertStaffUser(db, uid) {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists || snap.data()?.accountType !== 'staff') {
    throw new HttpsError('permission-denied', 'Staff access required.');
  }
}

exports.createStaffInvite = onCall({ region: 'us-central1' }, async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to create staff invites.');
    }

    const db = getFirestore();
    await assertStaffUser(db, request.auth.uid);

    const boundEmail = (request.data?.email || '').trim().toLowerCase() || null;
    const code = crypto.randomBytes(4).toString('hex').toUpperCase();
    const expiresAt = Timestamp.fromDate(
      new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    );

    await db.collection('staff_invites').doc(code).set({
      code,
      email: boundEmail,
      status: 'pending',
      createdBy: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt,
    });

    if (boundEmail) {
      const helpUrl = await loadInviteHelpUrl(db);
      const lines = [
        'You have been invited to Care Signal staff access.',
        '',
        `Sign in to the Care Signal app, open Staff access, and enter this code: ${code}`,
        '',
        'The code expires in 7 days.',
      ];
      if (helpUrl) lines.push('', `Learn more: ${helpUrl}`);
      const emailConfig = await loadEmailConfig(db);
      await sendAppEmail({
        apiKey: emailConfig.apiKey,
        from: emailConfig.from,
        to: boundEmail,
        subject: 'Care Signal staff access code',
        text: lines.join('\n'),
      });
    }

    return { code };
});

exports.redeemStaffInvite = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to redeem a staff code.');
  }

  const code = (request.data?.code || '').trim().toUpperCase();
  if (!code) {
    throw new HttpsError('invalid-argument', 'Enter a staff access code.');
  }

  const db = getFirestore();
  const inviteRef = db.collection('staff_invites').doc(code);
  const inviteSnap = await inviteRef.get();
  if (!inviteSnap.exists) {
    throw new HttpsError('not-found', 'That staff code is not valid.');
  }

  const invite = inviteSnap.data() || {};
  if (invite.status !== 'pending') {
    throw new HttpsError('failed-precondition', 'This staff code has already been used.');
  }

  const expiresAt = invite.expiresAt;
  if (
    expiresAt &&
    typeof expiresAt.toMillis === 'function' &&
    expiresAt.toMillis() < Date.now()
  ) {
    throw new HttpsError('deadline-exceeded', 'This staff code has expired.');
  }

  const boundEmail = (invite.email || '').trim().toLowerCase();
  const userEmail = (request.auth.token.email || '').trim().toLowerCase();
  if (boundEmail && userEmail && boundEmail !== userEmail) {
    throw new HttpsError(
      'permission-denied',
      'This code is tied to a different email address.',
    );
  }

  const uid = request.auth.uid;
  await db.collection('users').doc(uid).set(
    {
      accountType: 'staff',
      staffInviteCode: code,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await inviteRef.set(
    {
      status: 'redeemed',
      redeemedBy: uid,
      redeemedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { ok: true };
});

exports.resolveVolunteerByEmail = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to look up volunteers.');
  }

  const email = (request.data?.email || '').trim().toLowerCase();
  if (!email) {
    throw new HttpsError('invalid-argument', 'Enter an email address.');
  }

  const db = getFirestore();
  const snap = await db
    .collection('users')
    .where('email', '==', email)
    .where('accountType', '==', 'volunteer')
    .limit(1)
    .get();

  if (snap.empty) {
    return { found: false };
  }

  const doc = snap.docs[0];
  const data = doc.data() || {};
  if (data.backgroundCheckStatus !== 'approved') {
    return { found: false };
  }

  return {
    found: true,
    uid: doc.id,
    displayName: (data.displayName || 'Volunteer').trim(),
  };
});

async function findUserUidByEmail(db, email) {
  const normalized = (email || '').trim().toLowerCase();
  if (!normalized) return null;
  const snap = await db
    .collection('users')
    .where('email', '==', normalized)
    .limit(1)
    .get();
  if (snap.empty) return null;
  return snap.docs[0].id;
}

async function deleteCollectionDocuments(collectionRef, batchSize = 200) {
  let deleted = 0;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const snapshot = await collectionRef.limit(batchSize).get();
    if (snapshot.empty) return deleted;
    const batch = collectionRef.firestore.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += snapshot.size;
  }
}

async function deleteSupportConversations(db, uid) {
  const convos = await db
    .collection('users')
    .doc(uid)
    .collection('support_conversations')
    .get();
  for (const convo of convos.docs) {
    await deleteCollectionDocuments(convo.ref.collection('messages'));
    await convo.ref.delete();
  }
}

async function cleanupPeerGroupsForUser(db, uid) {
  const memberSnap = await db
    .collectionGroup('members')
    .where('memberUid', '==', uid)
    .get();
  for (const doc of memberSnap.docs) {
    await doc.ref.delete();
  }

  const cohostGroups = await db
    .collection('peer_groups')
    .where('cohostUids', 'array-contains', uid)
    .get();
  for (const doc of cohostGroups.docs) {
    const cohosts = (doc.data().cohostUids || []).filter((id) => id !== uid);
    await doc.ref.update({
      cohostUids: cohosts,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  const hostGroups = await db
    .collection('peer_groups')
    .where('hostUid', '==', uid)
    .get();
  for (const doc of hostGroups.docs) {
    const data = doc.data();
    const cohosts = [...(data.cohostUids || [])];
    if (cohosts.length > 0) {
      const newHost = cohosts.shift();
      await doc.ref.update({
        hostUid: newHost,
        cohostUids: cohosts,
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      await doc.ref.update({
        hostUid: FieldValue.delete(),
        archived: true,
        archivedReason: 'host_account_deleted',
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  }

  const peerRequests = await db
    .collection('users')
    .doc(uid)
    .collection('peer_group_requests')
    .get();
  for (const doc of peerRequests.docs) {
    const groupId = doc.id;
    await db
      .collection('peer_groups')
      .doc(groupId)
      .collection('join_requests')
      .doc(uid)
      .delete()
      .catch(() => {});
    await doc.ref.delete();
  }

  const cohostInvites = await db
    .collection('users')
    .doc(uid)
    .collection('peer_group_cohost_invites')
    .get();
  for (const doc of cohostInvites.docs) {
    const groupId = doc.id;
    await db
      .collection('peer_groups')
      .doc(groupId)
      .collection('cohost_invitations')
      .doc(uid)
      .delete()
      .catch(() => {});
    await doc.ref.delete();
  }

  await deleteCollectionDocuments(
    db.collection('users').doc(uid).collection('peer_group_invitations'),
  );
}

async function deleteVolunteerMessageThreads(db, uid) {
  const threads = await db
    .collection('users')
    .doc(uid)
    .collection('volunteer_messages')
    .get();
  for (const thread of threads.docs) {
    await deleteCollectionDocuments(thread.ref.collection('messages'));
    await thread.ref.delete();
  }
}

async function anonymizeFamilyChats(db, uid, familyId) {
  if (!familyId) return;
  const chats = await db
    .collection('families')
    .doc(familyId)
    .collection('family_chats')
    .where('participantUids', 'array-contains', uid)
    .get();

  for (const chat of chats.docs) {
    await chat.ref.set(
      {
        [`participantNames.${uid}`]: 'Deleted user',
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const messages = await chat.ref
      .collection('messages')
      .where('senderUid', '==', uid)
      .get();
    if (messages.empty) continue;

    const batch = db.batch();
    for (const message of messages.docs) {
      batch.update(message.ref, {
        senderName: 'Deleted user',
        text: '[message removed]',
      });
    }
    await batch.commit();
  }
}

async function anonymizeVolunteerRequestReferences(db, uid) {
  const uidFields = ['volunteerUid', 'counterVolunteerUid'];
  for (const field of uidFields) {
    const snap = await db
      .collectionGroup('volunteer_requests')
      .where(field, '==', uid)
      .get();
    for (const doc of snap.docs) {
      const updates = {
        [field]: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (field === 'volunteerUid') {
        updates.volunteerDisplayName = 'Deleted user';
      }
      await doc.ref.set(updates, { merge: true });
    }
  }
}

async function deleteUserSubcollections(db, uid) {
  const userRef = db.collection('users').doc(uid);
  const subcollections = [
    'daily_check_ins',
    'fcm_tokens',
    'notifications',
    'event_signups',
    'peer_group_requests',
    'peer_group_cohost_invites',
    'peer_group_invitations',
    'volunteer_requests',
    'background_check_application',
  ];

  for (const name of subcollections) {
    await deleteCollectionDocuments(userRef.collection(name));
  }

  await deleteSupportConversations(db, uid);
}

/**
 * Delete the signed-in user's auth account and remove personal data.
 */
exports.deleteUserAccount = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to delete your account.');
  }

  const uid = request.auth.uid;
  const db = getFirestore();
  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  const userData = userSnap.data() || {};
  const familyId = userData.familyId;

  await cleanupPeerGroupsForUser(db, uid);
  await anonymizeFamilyChats(db, uid, familyId);
  await anonymizeVolunteerRequestReferences(db, uid);
  await deleteVolunteerMessageThreads(db, uid);
  await deleteUserSubcollections(db, uid);
  await db.collection('partner_shares').doc(uid).delete();

  try {
    const bucket = getStorage().bucket();
    await bucket.file(`profile_photos/${uid}.jpg`).delete({ ignoreNotFound: true });
  } catch (err) {
    console.warn(`[deleteUserAccount] profile photo delete failed for ${uid}:`, err);
  }

  await userRef.set(
    {
      displayName: 'Deleted user',
      accountStatus: 'deleted',
      email: FieldValue.delete(),
      familyId: FieldValue.delete(),
      profilePhotoUrl: FieldValue.delete(),
      partnerWellnessSnapshot: FieldValue.delete(),
      volunteerCatalogId: FieldValue.delete(),
      volunteerOnline: false,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await getAuth().deleteUser(uid);
  return { ok: true };
});
