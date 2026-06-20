const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

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
