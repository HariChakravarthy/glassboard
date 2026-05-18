const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ── Helper: get FCM token for a user ───────────────────────────────
async function getFcmToken(uid) {
  const snap = await db.collection("users").doc(uid).get();
  return snap.exists ? snap.data().fcmToken || null : null;
}

// ── Helper: get users in a module ─────────────────────────────────
async function getUsersInModule(moduleId) {
  const snap = await db.collection("users")
    .where("moduleId", "==", moduleId).get();
  return snap.docs.map(d => d.data());
}

// ── Helper: store notification + send FCM ─────────────────────────
async function sendNotification({ recipientId, type, message, relatedId, fcmToken }) {
  // Store in Firestore
  await db.collection("notifications").add({
    recipientId,
    type,
    message,
    relatedId: relatedId || null,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  // Push FCM if token available
  if (fcmToken) {
    try {
      await getMessaging().send({
        token: fcmToken,
        notification: { title: "Glassboard", body: message },
        android: { priority: "high" },
        data: { type, relatedId: relatedId || "" },
      });
    } catch (e) {
      console.warn("FCM send failed:", e.message);
    }
  }
}

// ── Trigger 1: New handshake created → notify receiving module ─────
exports.onHandshakeCreated = onDocumentCreated(
  "handshakes/{handshakeId}",
  async (event) => {
    const hs = event.data.data();
    if (!hs) return;

    const toModuleSnap = await db.collection("modules").doc(hs.toModule).get();
    const toModuleName = toModuleSnap.exists ? toModuleSnap.data().name : hs.toModule;
    const fromModuleSnap = await db.collection("modules").doc(hs.fromModule).get();
    const fromModuleName = fromModuleSnap.exists ? fromModuleSnap.data().name : hs.fromModule;

    // Notify all leads in the receiving module
    const users = await getUsersInModule(hs.toModule);
    const leads = users.filter(u => u.role === "module_lead" || u.role === "org_admin");

    await Promise.all(leads.map(u =>
      sendNotification({
        recipientId: u.uid,
        type: "HANDSHAKE_RECEIVED",
        message: `📦 New handshake from ${fromModuleName} → ${toModuleName}. Review required.`,
        relatedId: event.params.handshakeId,
        fcmToken: u.fcmToken || null,
      })
    ));
  }
);

// ── Trigger 2: Handshake status updated → notify sender ───────────
exports.onHandshakeUpdated = onDocumentUpdated(
  "handshakes/{handshakeId}",
  async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return; // No status change

    const fromModuleSnap = await db.collection("modules").doc(after.fromModule).get();
    const fromModuleName = fromModuleSnap.exists ? fromModuleSnap.data().name : after.fromModule;
    const toModuleSnap   = await db.collection("modules").doc(after.toModule).get();
    const toModuleName   = toModuleSnap.exists ? toModuleSnap.data().name : after.toModule;

    // Find sender users
    const senders = await getUsersInModule(after.fromModule);

    let message = "";
    let type = "";
    if (after.status === "accepted") {
      message = `✅ Handshake from ${fromModuleName} → ${toModuleName} was ACCEPTED.`;
      type = "HANDSHAKE_ACCEPTED";
    } else if (after.status === "rejected") {
      const reason = after.rejectionReason ? `: "${after.rejectionReason}"` : ".";
      message = `❌ Handshake from ${fromModuleName} → ${toModuleName} was REJECTED${reason}`;
      type = "HANDSHAKE_REJECTED";
    } else {
      return; // Other status changes — skip
    }

    await Promise.all(senders.map(u =>
      sendNotification({
        recipientId: u.uid,
        type,
        message,
        relatedId: event.params.handshakeId,
        fcmToken: u.fcmToken || null,
      })
    ));
  }
);

// ── Trigger 3: Task assigned → notify assignee ────────────────────
exports.onTaskCreated = onDocumentCreated(
  "modules/{moduleId}/tasks/{taskId}",
  async (event) => {
    const task = event.data.data();
    if (!task || !task.assignedTo) return;

    const assigneeSnap = await db.collection("users").doc(task.assignedTo).get();
    if (!assigneeSnap.exists) return;
    const assignee = assigneeSnap.data();

    await sendNotification({
      recipientId: task.assignedTo,
      type: "TASK_ASSIGNED",
      message: `📋 You've been assigned: "${task.title}" (${task.priority || "MEDIUM"} priority)`,
      relatedId: event.params.moduleId,
      fcmToken: assignee.fcmToken || null,
    });
  }
);

// ── Trigger 4: File modified post-handshake → notify both modules ──
exports.onFileUpdated = onDocumentUpdated(
  "files/{fileId}",
  async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();
    if (!before || !after) return;
    if (before.currentVersion === after.currentVersion) return;

    const fileName = after.name || "a file";
    const scope    = after.moduleScope || [];

    // Gather all users in scoped modules
    const allUsers = (await Promise.all(
      scope.map(mid => getUsersInModule(mid))
    )).flat();

    const uniqueUsers = [...new Map(allUsers.map(u => [u.uid, u])).values()];

    await Promise.all(uniqueUsers.map(u =>
      sendNotification({
        recipientId: u.uid,
        type: "FILE_MODIFIED",
        message: `📎 "${fileName}" was updated to ${after.currentVersion}.`,
        relatedId: event.params.fileId,
        fcmToken: u.fcmToken || null,
      })
    ));
  }
);

// ── Trigger 5: Overdue handshake escalation (scheduled) ───────────
// Runs every hour — alerts org admins about pending handshakes > 24h old
const { onSchedule } = require("firebase-functions/v2/scheduler");

exports.escalateOverdueHandshakes = onSchedule("every 60 minutes", async () => {
  const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000); // 24 hours ago

  const snap = await db.collection("handshakes")
    .where("status", "==", "pending")
    .where("timestamp", "<", cutoff)
    .get();

  if (snap.empty) return;

  // Find all org admins
  const adminsSnap = await db.collection("users")
    .where("role", "==", "org_admin").get();
  const admins = adminsSnap.docs.map(d => d.data());

  await Promise.all(
    snap.docs.flatMap(doc => {
      const hs = doc.data();
      return admins.map(admin =>
        sendNotification({
          recipientId: admin.uid,
          type: "HANDSHAKE_OVERDUE",
          message: `⚠️ Handshake ${doc.id.substring(0, 8)} has been pending for over 24 hours.`,
          relatedId: doc.id,
          fcmToken: admin.fcmToken || null,
        })
      );
    })
  );
});
