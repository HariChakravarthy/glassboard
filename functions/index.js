const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError }                   = require("firebase-functions/v2/https");
const { onSchedule }                           = require("firebase-functions/v2/scheduler");
const { initializeApp }                        = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp }  = require("firebase-admin/firestore");
const { getMessaging }                         = require("firebase-admin/messaging");
const nodemailer                               = require("nodemailer");
const ExcelJS                                  = require("exceljs");
const sgMail                                   = require("@sendgrid/mail");

initializeApp();
const db = getFirestore();

// ── Email credentials from .env file ────────────────────────────────
const GMAIL_USER       = process.env.GMAIL_USER || "";
const GMAIL_PASS       = process.env.GMAIL_PASS || "";
const SENDGRID_API_KEY = process.env.SENDGRID_API_KEY || "";
const SMTP_FROM        = process.env.SMTP_FROM || (GMAIL_USER ? `"Glassboard" <${GMAIL_USER}>` : `"Glassboard" <noreply@glassboard.app>`);
const SMTP_HOST        = process.env.SMTP_HOST || "";
const SMTP_PORT        = process.env.SMTP_PORT || "465";
const SMTP_SECURE      = process.env.SMTP_SECURE !== "false"; // default to true (use TLS/SSL)
const SMTP_USER        = process.env.SMTP_USER || "";
const SMTP_PASS        = process.env.SMTP_PASS || "";

// ── Helper: build Nodemailer transporter ────────────────────────────
function createTransporter(user, pass) {
  const finalUser = user || SMTP_USER || GMAIL_USER;
  const finalPass = pass || SMTP_PASS || GMAIL_PASS;

  if (SMTP_HOST && SMTP_USER && SMTP_PASS) {
    return nodemailer.createTransport({
      host: SMTP_HOST,
      port: parseInt(SMTP_PORT, 10),
      secure: SMTP_SECURE,
      auth: {
        user: finalUser,
        pass: finalPass,
      },
    });
  }

  // Fallback to Gmail service
  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: finalUser,
      pass: finalPass,
    },
  });
}

// ── Helper: get FCM token for a user ────────────────────────────────
async function getFcmToken(uid) {
  const snap = await db.collection("users").doc(uid).get();
  return snap.exists ? snap.data().fcmToken || null : null;
}

// ── Helper: get users in a module ───────────────────────────────────
async function getUsersInModule(moduleId) {
  const snap = await db.collection("users")
    .where("moduleId", "==", moduleId).get();
  return snap.docs.map(d => d.data());
}

// ── Helper: store Firestore notification + send FCM push ─────────────
async function sendNotification({ recipientId, type, message, relatedId, fcmToken }) {
  // Store in Firestore notifications collection
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

// ── Helper: send styled HTML email ──────────────────────────────────
async function sendEmail({ toEmail, subject, bodyHtml, attachment, gmailUserVal, gmailPassVal }) {
  if (!toEmail) {
    console.warn("No recipient email. Skipping email.");
    return;
  }

  // 1. Try SendGrid if API Key is configured
  if (SENDGRID_API_KEY) {
    try {
      sgMail.setApiKey(SENDGRID_API_KEY);
      const msg = {
        to: toEmail,
        from: SMTP_FROM,
        subject,
        html: `
          <div style="font-family: Arial, sans-serif; background: #0D0D0D; color: #E0E0E0;
                      padding: 32px; border-radius: 8px; max-width: 600px; margin: auto;">
            <div style="border-left: 4px solid #00E5FF; padding-left: 16px; margin-bottom: 24px;">
              <h2 style="margin: 0; color: #00E5FF; font-size: 20px; letter-spacing: 2px;">
                GLASSBOARD
              </h2>
              <p style="margin: 4px 0 0; color: #7E7E7E; font-size: 11px; letter-spacing: 1px;">
                PROJECT HANDSHAKE PLATFORM
              </p>
            </div>
            ${bodyHtml}
            <hr style="border: none; border-top: 1px solid #2A2A2A; margin: 24px 0;" />
            <p style="color: #4A4A4A; font-size: 10px;">
              This is an automated message from Glassboard. Do not reply to this email.
            </p>
          </div>
        `,
      };

      if (attachment) {
        msg.attachments = [
          {
            content: attachment.content.toString("base64"),
            filename: attachment.filename,
            type: attachment.contentType,
            disposition: "attachment",
          },
        ];
      }

      await sgMail.send(msg);
      console.log(`Email sent via SendGrid to ${toEmail}: ${subject}`);
      return;
    } catch (e) {
      console.error("SendGrid email send failed:", e.message);
      if (e.response && e.response.body) {
        console.error("SendGrid error body:", JSON.stringify(e.response.body));
      }
      console.log("Attempting fallback to Nodemailer/SMTP...");
    }
  }

  // 2. Fallback to Nodemailer (SMTP or Gmail)
  const isGmailConfigured = (gmailUserVal && gmailPassVal) || (GMAIL_USER && GMAIL_PASS);
  const isSmtpConfigured = SMTP_HOST && SMTP_USER && SMTP_PASS;

  if (!isGmailConfigured && !isSmtpConfigured) {
    console.warn("No email credentials (SendGrid, SMTP, or Gmail) configured. Skipping email.");
    return;
  }

  try {
    const transporter = createTransporter(gmailUserVal, gmailPassVal);
    const mailOptions = {
      from: SMTP_FROM,
      to: toEmail,
      subject,
      html: `
        <div style="font-family: Arial, sans-serif; background: #0D0D0D; color: #E0E0E0;
                    padding: 32px; border-radius: 8px; max-width: 600px; margin: auto;">
          <div style="border-left: 4px solid #00E5FF; padding-left: 16px; margin-bottom: 24px;">
            <h2 style="margin: 0; color: #00E5FF; font-size: 20px; letter-spacing: 2px;">
              GLASSBOARD
            </h2>
            <p style="margin: 4px 0 0; color: #7E7E7E; font-size: 11px; letter-spacing: 1px;">
              PROJECT HANDSHAKE PLATFORM
            </p>
          </div>
          ${bodyHtml}
          <hr style="border: none; border-top: 1px solid #2A2A2A; margin: 24px 0;" />
          <p style="color: #4A4A4A; font-size: 10px;">
            This is an automated message from Glassboard. Do not reply to this email.
          </p>
        </div>
      `,
    };

    if (attachment) {
      mailOptions.attachments = [attachment];
    }

    await transporter.sendMail(mailOptions);
    console.log(`Email sent via SMTP/Nodemailer to ${toEmail}: ${subject}`);
  } catch (e) {
    console.error("SMTP/Nodemailer email send failed:", e.message);
  }
}

// ── Email body templates ─────────────────────────────────────────────
function handshakeReceivedEmailHtml({ fromModuleName, toModuleName, proofNote }) {
  return `
    <h3 style="color: #FFC107; margin: 0 0 16px;">📦 New Handshake Received</h3>
    <table style="width: 100%; border-collapse: collapse;">
      <tr><td style="padding: 8px; color: #7E7E7E; font-size: 12px;">From Module</td>
          <td style="padding: 8px; color: #E0E0E0; font-size: 13px; font-weight: bold;">${fromModuleName}</td></tr>
      <tr><td style="padding: 8px; color: #7E7E7E; font-size: 12px;">To Module</td>
          <td style="padding: 8px; color: #E0E0E0; font-size: 13px; font-weight: bold;">${toModuleName}</td></tr>
      ${proofNote ? `<tr><td style="padding: 8px; color: #7E7E7E; font-size: 12px;">Delivery Note</td>
          <td style="padding: 8px; color: #E0E0E0; font-size: 13px;">${proofNote}</td></tr>` : ""}
    </table>
    <p style="color: #B0B0B0; font-size: 13px; margin-top: 16px;">
      A new handshake is waiting for your review. Please open Glassboard to Accept or Reject.
    </p>
  `;
}

function handshakeAcceptedEmailHtml({ fromModuleName, toModuleName }) {
  return `
    <h3 style="color: #00E676; margin: 0 0 16px;">✅ Handshake Accepted</h3>
    <p style="color: #B0B0B0; font-size: 13px;">
      Your handshake from <strong style="color: #E0E0E0;">${fromModuleName}</strong> to
      <strong style="color: #E0E0E0;">${toModuleName}</strong> has been <strong style="color: #00E676;">ACCEPTED</strong>.
    </p>
    <p style="color: #B0B0B0; font-size: 13px;">The delivery has been confirmed and logged in the audit trail.</p>
  `;
}

function handshakeRejectedEmailHtml({ fromModuleName, toModuleName, reason }) {
  return `
    <h3 style="color: #F44336; margin: 0 0 16px;">❌ Handshake Rejected</h3>
    <p style="color: #B0B0B0; font-size: 13px;">
      Your handshake from <strong style="color: #E0E0E0;">${fromModuleName}</strong> to
      <strong style="color: #E0E0E0;">${toModuleName}</strong> has been <strong style="color: #F44336;">REJECTED</strong>.
    </p>
    ${reason ? `
    <div style="background: #1A1A1A; border-left: 3px solid #F44336; padding: 12px; margin-top: 12px; border-radius: 4px;">
      <p style="margin: 0; color: #7E7E7E; font-size: 11px; letter-spacing: 1px;">REJECTION REASON</p>
      <p style="margin: 6px 0 0; color: #E0E0E0; font-size: 13px;">${reason}</p>
    </div>` : ""}
    <p style="color: #B0B0B0; font-size: 13px; margin-top: 16px;">
      Please review the feedback, update your work, and re-submit the handshake.
    </p>
  `;
}

function taskAssignedEmailHtml({ taskTitle, priority, moduleName }) {
  const priorityColor = priority === "BLOCKER" ? "#F44336"
    : priority === "HIGH" ? "#FF6D00"
    : priority === "MEDIUM" ? "#FFC107"
    : "#7E7E7E";
  return `
    <h3 style="color: #00E5FF; margin: 0 0 16px;">📋 New Task Assigned to You</h3>
    <table style="width: 100%; border-collapse: collapse;">
      <tr><td style="padding: 8px; color: #7E7E7E; font-size: 12px;">Task</td>
          <td style="padding: 8px; color: #E0E0E0; font-size: 13px; font-weight: bold;">${taskTitle}</td></tr>
      <tr><td style="padding: 8px; color: #7E7E7E; font-size: 12px;">Module</td>
          <td style="padding: 8px; color: #E0E0E0; font-size: 13px;">${moduleName || "—"}</td></tr>
      <tr><td style="padding: 8px; color: #7E7E7E; font-size: 12px;">Priority</td>
          <td style="padding: 8px; font-size: 13px; font-weight: bold; color: ${priorityColor};">${priority}</td></tr>
    </table>
    <p style="color: #B0B0B0; font-size: 13px; margin-top: 16px;">
      Please open Glassboard to view your task details and mark progress.
    </p>
  `;
}

// ══════════════════════════════════════════════════════════════════════
// TRIGGER 1: New handshake created → notify receiving module (FCM + Email)
// ══════════════════════════════════════════════════════════════════════
exports.onHandshakeCreated = onDocumentCreated(
  "handshakes/{handshakeId}",
  async (event) => {
    const hs = event.data.data();
    if (!hs) return;

    const toModuleSnap   = await db.collection("modules").doc(hs.toModule).get();
    const fromModuleSnap = await db.collection("modules").doc(hs.fromModule).get();
    const fromModuleName = fromModuleSnap.exists ? fromModuleSnap.data().name : hs.fromModule;
    const toModuleName   = toModuleSnap.exists   ? toModuleSnap.data().name   : hs.toModule;

    const users = await getUsersInModule(hs.toModule);
    const leads = users.filter(u => u.role === "module_lead" || u.role === "org_admin");

    await Promise.all(leads.map(async (u) => {
      // FCM + Firestore notification
      await sendNotification({
        recipientId: u.uid,
        type: "HANDSHAKE_RECEIVED",
        message: `📦 New handshake from ${fromModuleName} → ${toModuleName}. Review required.`,
        relatedId: event.params.handshakeId,
        fcmToken: u.fcmToken || null,
      });

      // Email backup notification
      await sendEmail({
        toEmail: u.email,
        subject: `📦 [Glassboard] New Handshake: ${fromModuleName} → ${toModuleName}`,
        bodyHtml: handshakeReceivedEmailHtml({
          fromModuleName,
          toModuleName,
          proofNote: hs.proofNote || "",
        }),
        gmailUserVal: GMAIL_USER,
        gmailPassVal: GMAIL_PASS,
      });
    }));
  }
);

// ══════════════════════════════════════════════════════════════════════
// TRIGGER 2: Handshake status updated → notify sender (FCM + Email)
// ══════════════════════════════════════════════════════════════════════
exports.onHandshakeUpdated = onDocumentUpdated(
  "handshakes/{handshakeId}",
  async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;

    const fromModuleSnap = await db.collection("modules").doc(after.fromModule).get();
    const toModuleSnap   = await db.collection("modules").doc(after.toModule).get();
    const fromModuleName = fromModuleSnap.exists ? fromModuleSnap.data().name : after.fromModule;
    const toModuleName   = toModuleSnap.exists   ? toModuleSnap.data().name   : after.toModule;

    const senders = await getUsersInModule(after.fromModule);

    let message = "";
    let type    = "";
    let emailBodyHtml = "";
    let emailSubject  = "";

    if (after.status === "accepted") {
      message      = `✅ Handshake from ${fromModuleName} → ${toModuleName} was ACCEPTED.`;
      type         = "HANDSHAKE_ACCEPTED";
      emailSubject = `✅ [Glassboard] Handshake Accepted: ${fromModuleName} → ${toModuleName}`;
      emailBodyHtml = handshakeAcceptedEmailHtml({ fromModuleName, toModuleName });
    } else if (after.status === "rejected") {
      const reason = after.rejectionReason || "";
      message      = `❌ Handshake from ${fromModuleName} → ${toModuleName} was REJECTED${reason ? `: "${reason}"` : "."}`;
      type         = "HANDSHAKE_REJECTED";
      emailSubject = `❌ [Glassboard] Handshake Rejected: ${fromModuleName} → ${toModuleName}`;
      emailBodyHtml = handshakeRejectedEmailHtml({ fromModuleName, toModuleName, reason });
    } else {
      return;
    }

    await Promise.all(senders.map(async (u) => {
      await sendNotification({
        recipientId: u.uid,
        type,
        message,
        relatedId: event.params.handshakeId,
        fcmToken: u.fcmToken || null,
      });

      await sendEmail({
        toEmail: u.email,
        subject: emailSubject,
        bodyHtml: emailBodyHtml,
        gmailUserVal: GMAIL_USER,
        gmailPassVal: GMAIL_PASS,
      });
    }));
  }
);

// ══════════════════════════════════════════════════════════════════════
// TRIGGER 3: Task assigned → notify assignee (FCM + Email)
// ══════════════════════════════════════════════════════════════════════
exports.onTaskCreated = onDocumentCreated(
  "modules/{moduleId}/tasks/{taskId}",
  async (event) => {
    const task = event.data.data();
    if (!task || !task.assignedTo) return;

    const assigneeSnap = await db.collection("users").doc(task.assignedTo).get();
    if (!assigneeSnap.exists) return;
    const assignee = assigneeSnap.data();

    const moduleSnap = await db.collection("modules").doc(event.params.moduleId).get();
    const moduleName = moduleSnap.exists ? moduleSnap.data().name : event.params.moduleId;

    await sendNotification({
      recipientId: task.assignedTo,
      type: "TASK_ASSIGNED",
      message: `📋 You've been assigned: "${task.title}" (${task.priority || "MEDIUM"} priority)`,
      relatedId: event.params.moduleId,
      fcmToken: assignee.fcmToken || null,
    });

    await sendEmail({
      toEmail: assignee.email,
      subject: `📋 [Glassboard] New Task Assigned: "${task.title}"`,
      bodyHtml: taskAssignedEmailHtml({
        taskTitle: task.title,
        priority: task.priority || "MEDIUM",
        moduleName,
      }),
      gmailUserVal: GMAIL_USER,
      gmailPassVal: GMAIL_PASS,
    });
  }
);

// ══════════════════════════════════════════════════════════════════════
// TRIGGER 4: File modified → notify scoped modules (FCM only)
// ══════════════════════════════════════════════════════════════════════
exports.onFileUpdated = onDocumentUpdated(
  "files/{fileId}",
  async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();
    if (!before || !after) return;
    if (before.currentVersion === after.currentVersion) return;

    const fileName = after.name || "a file";
    const scope    = after.moduleScope || [];

    const allUsers    = (await Promise.all(scope.map(mid => getUsersInModule(mid)))).flat();
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

// ══════════════════════════════════════════════════════════════════════
// TRIGGER 5: Overdue handshake escalation — runs every hour (FCM only)
// ══════════════════════════════════════════════════════════════════════
exports.escalateOverdueHandshakes = onSchedule("every 60 minutes", async () => {
  const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);

  const snap = await db.collection("handshakes")
    .where("status", "==", "pending")
    .where("timestamp", "<", cutoff)
    .get();

  if (snap.empty) return;

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

// ══════════════════════════════════════════════════════════════════════
// FEATURE 7: HTTPS Callable — Export Audit Log as Excel & Email it
// ══════════════════════════════════════════════════════════════════════
exports.exportAuditReportEmail = onCall(
  async (request) => {
    // Auth guard
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const { orgId, email } = request.data;
    if (!orgId || !email) {
      throw new HttpsError("invalid-argument", "orgId and email are required.");
    }

    // 1. Fetch org details
    const orgSnap = await db.collection("organizations").doc(orgId).get();
    const orgName = orgSnap.exists ? (orgSnap.data().name || orgId) : orgId;

    // 2. Fetch all audit logs for the org
    const auditSnap = await db.collection("audits")
      .where("orgId", "==", orgId)
      .orderBy("timestamp", "desc")
      .limit(500)
      .get();

    const logs = auditSnap.docs.map(doc => {
      const d = doc.data();
      const ts = d.timestamp instanceof Timestamp ? d.timestamp.toDate() : new Date();
      return {
        timestamp: ts,
        action: d.action || "",
        actorName: d.actorName || d.actorId || "",
        targetModule: d.targetModule || "",
        metadata: d.metadata ? Object.entries(d.metadata).map(([k, v]) => `${k}: ${v}`).join(" | ") : "",
      };
    });

    // 3. Build Excel workbook using ExcelJS
    const workbook  = new ExcelJS.Workbook();
    workbook.creator = "Glassboard";
    workbook.created = new Date();

    // ── Summary sheet ──────────────────────────────────────────────
    const summarySheet = workbook.addWorksheet("Summary");
    summarySheet.columns = [
      { width: 28 },
      { width: 20 },
    ];

    // Title block
    summarySheet.mergeCells("A1:B1");
    const titleCell = summarySheet.getCell("A1");
    titleCell.value = "GLASSBOARD AUDIT REPORT";
    titleCell.font  = { bold: true, size: 16, color: { argb: "FF00E5FF" } };
    titleCell.fill  = { type: "pattern", pattern: "solid", fgColor: { argb: "FF0D0D0D" } };
    titleCell.alignment = { horizontal: "center" };

    summarySheet.mergeCells("A2:B2");
    const subCell  = summarySheet.getCell("A2");
    subCell.value  = `Organization: ${orgName}`;
    subCell.font   = { size: 12, color: { argb: "FFB0B0B0" } };
    subCell.fill   = { type: "pattern", pattern: "solid", fgColor: { argb: "FF0D0D0D" } };
    subCell.alignment = { horizontal: "center" };

    summarySheet.mergeCells("A3:B3");
    const dateCell  = summarySheet.getCell("A3");
    dateCell.value  = `Generated: ${new Date().toLocaleString("en-IN", { timeZone: "Asia/Kolkata" })} IST`;
    dateCell.font   = { size: 10, color: { argb: "FF7E7E7E" } };
    dateCell.fill   = { type: "pattern", pattern: "solid", fgColor: { argb: "FF0D0D0D" } };
    dateCell.alignment = { horizontal: "center" };

    summarySheet.addRow([]);

    // Summary stats
    const totalLogs      = logs.length;
    const handshakeLogs  = logs.filter(l => l.action.includes("HANDSHAKE")).length;
    const taskLogs       = logs.filter(l => l.action.includes("TASK")).length;
    const fileLogs       = logs.filter(l => l.action.includes("FILE")).length;
    const acceptedLogs   = logs.filter(l => l.action.includes("ACCEPTED")).length;
    const rejectedLogs   = logs.filter(l => l.action.includes("REJECTED")).length;

    const statsHeaderStyle = {
      font: { bold: true, color: { argb: "FF00E5FF" } },
      fill: { type: "pattern", pattern: "solid", fgColor: { argb: "FF1A1A2E" } },
    };

    const addStat = (label, value, valueColor = "FFE0E0E0") => {
      const row = summarySheet.addRow([label, value]);
      row.getCell(1).font = { color: { argb: "FF7E7E7E" }, size: 11 };
      row.getCell(1).fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF111111" } };
      row.getCell(2).font = { bold: true, color: { argb: valueColor }, size: 11 };
      row.getCell(2).fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF111111" } };
      row.getCell(2).alignment = { horizontal: "right" };
    };

    const statsLabelRow = summarySheet.addRow(["Metric", "Value"]);
    statsLabelRow.eachCell(cell => Object.assign(cell, statsHeaderStyle));
    addStat("Total Audit Entries",   totalLogs);
    addStat("Handshake Events",      handshakeLogs, "FFFFC107");
    addStat("Task Events",           taskLogs,      "FF00E5FF");
    addStat("File Events",           fileLogs,      "FFCE93D8");
    addStat("Accepted Handshakes",   acceptedLogs,  "FF00E676");
    addStat("Rejected Handshakes",   rejectedLogs,  "FFF44336");

    // ── Audit Log sheet ────────────────────────────────────────────
    const auditSheet = workbook.addWorksheet("Audit Log");

    auditSheet.columns = [
      { header: "Timestamp",    key: "timestamp",    width: 22 },
      { header: "Action",       key: "action",       width: 30 },
      { header: "Actor",        key: "actorName",    width: 24 },
      { header: "Module",       key: "targetModule", width: 28 },
      { header: "Details",      key: "metadata",     width: 55 },
    ];

    // Style header row
    const headerRow = auditSheet.getRow(1);
    headerRow.eachCell(cell => {
      cell.font      = { bold: true, color: { argb: "FF00E5FF" }, size: 11 };
      cell.fill      = { type: "pattern", pattern: "solid", fgColor: { argb: "FF0D0D0D" } };
      cell.alignment = { horizontal: "center", vertical: "middle" };
      cell.border    = {
        bottom: { style: "thin", color: { argb: "FF00E5FF" } },
      };
    });
    headerRow.height = 24;

    // Add data rows with conditional coloring
    logs.forEach((log, idx) => {
      const row = auditSheet.addRow({
        timestamp:    log.timestamp.toLocaleString("en-IN", { timeZone: "Asia/Kolkata" }),
        action:       log.action,
        actorName:    log.actorName,
        targetModule: log.targetModule,
        metadata:     log.metadata,
      });

      const bgColor = idx % 2 === 0 ? "FF111111" : "FF161616";
      let actionColor = "FFE0E0E0";
      if (log.action.includes("ACCEPTED")) actionColor = "FF00E676";
      else if (log.action.includes("REJECTED")) actionColor = "FFF44336";
      else if (log.action.includes("HANDSHAKE")) actionColor = "FFFFC107";
      else if (log.action.includes("FILE")) actionColor = "FFCE93D8";
      else if (log.action.includes("TASK")) actionColor = "FF00E5FF";

      row.eachCell(cell => {
        cell.fill      = { type: "pattern", pattern: "solid", fgColor: { argb: bgColor } };
        cell.font      = { color: { argb: "FFB0B0B0" }, size: 10 };
        cell.alignment = { vertical: "middle", wrapText: true };
      });
      // Color the action cell distinctly
      row.getCell("action").font = { bold: true, color: { argb: actionColor }, size: 10 };
      row.height = 18;
    });

    // Freeze header row
    auditSheet.views = [{ state: "frozen", ySplit: 1 }];

    // 4. Export workbook to buffer
    const buffer = await workbook.xlsx.writeBuffer();

    // 5. Send email with attachment
    const dateLabel = new Date().toISOString().substring(0, 10);
    await sendEmail({
      toEmail: email,
      subject: `📊 [Glassboard] Audit Report — ${orgName} (${dateLabel})`,
      bodyHtml: `
        <h3 style="color: #00E676; margin: 0 0 16px;">📊 Audit Report Ready</h3>
        <p style="color: #B0B0B0; font-size: 13px;">
          Your Glassboard audit log export for <strong style="color: #E0E0E0;">${orgName}</strong> is attached as an Excel file.
        </p>
        <ul style="color: #B0B0B0; font-size: 13px; padding-left: 20px;">
          <li>Total Entries: <strong style="color: #E0E0E0;">${totalLogs}</strong></li>
          <li>Handshake Events: <strong style="color: #FFC107;">${handshakeLogs}</strong></li>
          <li>Task Events: <strong style="color: #00E5FF;">${taskLogs}</strong></li>
          <li>Accepted: <strong style="color: #00E676;">${acceptedLogs}</strong></li>
          <li>Rejected: <strong style="color: #F44336;">${rejectedLogs}</strong></li>
        </ul>
        <p style="color: #7E7E7E; font-size: 12px; margin-top: 16px;">
          The Excel file contains a Summary sheet and a full Audit Log sheet with color-coded entries.
        </p>
      `,
      attachment: {
        filename: `glassboard_audit_${orgName.replace(/\s+/g, "_")}_${dateLabel}.xlsx`,
        content: buffer,
        contentType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      },
    });

    console.log(`Audit Excel report sent to ${email} for orgId=${orgId}`);
    return { success: true, message: `Report sent to ${email}` };
  }
);
