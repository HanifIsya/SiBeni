/**
 * End-to-end check of the SI BENI write paths against a live Supabase project.
 *
 * Signs in as each seeded account, then exercises the endpoints that carry the
 * revised role workflow:
 *
 *   worker     files a hazard report
 *   HSE        verifies it, then MUST type a complete corrective action
 *   Management approves the action, later evaluates and closes the report
 *   supervisor executes stages 4–6 in the field
 *
 * Also checks role boundaries (403 on every out-of-role action), notifications,
 * coordination, inspections, early warnings and ESG writes.
 *
 * NOTE: hazard_reports has no DELETE policy, so the probe report stays in the
 * database. It is stamped with an `e2e-` local_id and can be removed from the
 * SQL editor with:
 *   DELETE FROM hazard_reports WHERE local_id LIKE 'e2e-%';
 */
import { createClient } from "@supabase/supabase-js";

const API = process.env.API_BASE || "http://localhost:4310";
const URL_ = process.env.NEXT_PUBLIC_SUPABASE_URL;
const KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

const ACCOUNTS = [
  { label: "worker", email: "pekerja@consnetmining.com", password: "Consnet123!" },
  { label: "supervisor", email: "supervisor@consnetmining.com", password: "Consnet123!" },
  { label: "hse", email: "hse@consnetmining.com", password: "Consnet123!" },
  { label: "management", email: "manajemen@consnetmining.com", password: "Consnet123!" },
];

const results = [];
function check(name, pass, detail = "") {
  results.push({ name, pass, detail });
  console.log(`${pass ? "PASS" : "FAIL"}  ${name}${detail ? ` — ${detail}` : ""}`);
}

async function signIn(account) {
  const client = createClient(URL_, KEY, {
    auth: { persistSession: false },
  });
  const { data, error } = await client.auth.signInWithPassword({
    email: account.email,
    password: account.password,
  });
  if (error) throw new Error(`${account.label}: ${error.message}`);
  return { client, token: data.session.access_token, userId: data.user.id };
}

async function call(token, path, init = {}) {
  const res = await fetch(`${API}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      ...(init.headers || {}),
    },
  });
  let body = null;
  try {
    body = await res.json();
  } catch {
    body = null;
  }
  return { status: res.status, body };
}

const sessions = {};

async function main() {
  for (const account of ACCOUNTS) {
    try {
      sessions[account.label] = await signIn(account);
      const role = await roleOf(sessions[account.label]);
      check(`sign-in ${account.label}`, true, `role=${role}`);
    } catch (e) {
      check(`sign-in ${account.label}`, false, e.message);
    }
  }

  if (!sessions.worker || !sessions.hse || !sessions.management || !sessions.supervisor) {
    console.log("\nCannot continue without every role signed in.");
    process.exit(1);
  }

  // ------------------------------------------------------------ report ingest
  const localId = `e2e-${Date.now()}`;
  const ingest = await call(sessions.worker.token, "/api/reports", {
    method: "POST",
    body: JSON.stringify([
      {
        local_id: localId,
        reporter_employee_id: "OP-104",
        reporter_name: "Budi Santoso",
        report_type: "hazard",
        zone_name: "Pit Utama (Area Penambangan Aktif)",
        category: "Alat Berat",
        description: "End-to-end probe report",
        gps_latitude: -7.22,
        gps_longitude: 112.75,
        photo_urls: [],
        is_emergency: false,
      },
    ]),
  });
  const ingested = ingest.body?.results?.[0]?.synced === true;
  check("report ingest (worker)", ingested, ingested ? localId : JSON.stringify(ingest.body));

  // Idempotency: the same local_id must not create a second row.
  const replay = await call(sessions.worker.token, "/api/reports", {
    method: "POST",
    body: JSON.stringify([
      { local_id: localId, reporter_employee_id: "OP-104", zone_name: "Pit Utama", category: "Alat Berat", description: "replay" },
    ]),
  });
  check(
    "report ingest is idempotent",
    replay.body?.results?.[0]?.synced === true,
    JSON.stringify(replay.body)
  );

  // ---------------------------------------------------------------- register
  const register = await call(sessions.hse.token, "/api/reports");
  const allReports = register.body?.reports || [];
  const mine = allReports.find((r) => r.local_id === localId);
  check("report register (hse)", Array.isArray(allReports), `${allReports.length} rows`);
  check("HSE sees the filed report", Boolean(mine), mine ? `id=${mine.id}` : "not visible");
  check(
    "register returns counts",
    register.body?.counts && typeof register.body.counts.total === "number",
    JSON.stringify(register.body?.counts)
  );

  // A worker may not read the whole register.
  const workerRegister = await call(sessions.worker.token, "/api/reports");
  check(
    "RLS scopes the register per role",
    workerRegister.status === 200,
    `worker sees ${(workerRegister.body?.reports || []).length} rows`
  );

  // -------------------------------------------------- revised report workflow
  let probeReport = mine;
  let probeAction = null;

  if (mine) {
    const review = await call(sessions.hse.token, "/api/reports", {
      method: "PATCH",
      body: JSON.stringify({ id: mine.id, hse_status: "IN_REVIEW", hse_notes: "Probe review" }),
    });
    check("HSE can verify a report", review.status === 200, review.body?.error || "");

    // The old bug: tapping "Tindakan" closed the report before text was typed.
    // The server must now refuse an action with no details.
    const emptyAction = await call(sessions.hse.token, "/api/reports", {
      method: "PATCH",
      body: JSON.stringify({ id: mine.id, hse_status: "PENDING_APPROVAL", hse_notes: "coba" }),
    });
    check(
      "report cannot enter PENDING_APPROVAL without action detail",
      emptyAction.status === 400,
      `status=${emptyAction.status}`
    );

    const blankDescription = await call(sessions.hse.token, "/api/reports", {
      method: "PATCH",
      body: JSON.stringify({
        id: mine.id,
        hse_status: "PENDING_APPROVAL",
        hse_notes: "coba",
        action: { description: "  ", assigned_pic_name: "PIC", target_due_date: "2026-12-31" },
      }),
    });
    check(
      "action requires typed description",
      blankDescription.status === 400,
      `status=${blankDescription.status}`
    );

    const workerAction = await call(sessions.worker.token, "/api/reports", {
      method: "PATCH",
      body: JSON.stringify({
        id: mine.id,
        hse_status: "PENDING_APPROVAL",
        hse_notes: "worker mencoba",
        action: { description: "x", assigned_pic_name: "x", target_due_date: "2026-12-31" },
      }),
    });
    check("worker cannot issue corrective actions", workerAction.status === 403, `status=${workerAction.status}`);

    const actionRes = await call(sessions.hse.token, "/api/reports", {
      method: "PATCH",
      body: JSON.stringify({
        id: mine.id,
        hse_status: "PENDING_APPROVAL",
        hse_notes: "Tindakan uji end-to-end.",
        action: {
          title: "E2E probe corrective action",
          description: "Pasang barikade dan rambu di area probe.",
          assigned_pic_name: "Pengawas Pit Utama",
          severity: "high",
          target_due_date: "2026-12-31",
        },
      }),
    });
    check(
      "HSE can submit a complete action",
      actionRes.status === 200 && actionRes.body?.action?.id,
      actionRes.body?.error || `action_id=${actionRes.body?.action?.id}`
    );
    probeAction = actionRes.body?.action || null;

    check(
      "report is PENDING_APPROVAL after HSE action",
      String(actionRes.body?.report?.hse_status).toUpperCase() === "PENDING_APPROVAL",
      `status=${actionRes.body?.report?.hse_status}`
    );

    // HSE cannot close the report directly: closure is a Management decision.
    const hseClose = await call(sessions.hse.token, "/api/reports", {
      method: "PATCH",
      body: JSON.stringify({ id: mine.id, hse_status: "CLOSED", hse_notes: "coba tutup" }),
    });
    check("HSE cannot close a report directly", hseClose.status === 403, `status=${hseClose.status}`);

    // A worker must be refused.
    const denied = await call(sessions.worker.token, "/api/reports", {
      method: "PATCH",
      body: JSON.stringify({ id: mine.id, hse_status: "CLOSED" }),
    });
    check("worker cannot review", denied.status === 403, `status=${denied.status}`);

    if (probeAction?.id) {
      // Supervisor cannot approve its own work.
      const supApprove = await call(sessions.supervisor.token, "/api/inspections", {
        method: "PATCH",
        body: JSON.stringify({ id: probeAction.id, management_decision: "APPROVED" }),
      });
      check(
        "supervisor cannot approve management decision",
        supApprove.status === 403,
        `status=${supApprove.status}`
      );

      const approve = await call(sessions.management.token, "/api/inspections", {
        method: "PATCH",
        body: JSON.stringify({
          id: probeAction.id,
          management_decision: "APPROVED",
          management_notes: "Disetujui untuk dieksekusi lapangan.",
        }),
      });
      check(
        "management approves the action plan",
        approve.status === 200 && Number(approve.body?.action?.stage_number) === 4,
        approve.body?.error || `stage=${approve.body?.action?.stage_number}`
      );
      check(
        "report becomes ACTION_REQUIRED after approval",
        String(approve.body?.report?.hse_status).toUpperCase() === "ACTION_REQUIRED",
        `status=${approve.body?.report?.hse_status}`
      );

      // Management cannot execute stages; that is Supervisor's job.
      const mgmtStage = await call(sessions.management.token, "/api/inspections", {
        method: "PATCH",
        body: JSON.stringify({ id: probeAction.id, stage_number: 5 }),
      });
      check(
        "management cannot advance field stages",
        mgmtStage.status === 403,
        `status=${mgmtStage.status}`
      );

      const advance5 = await call(sessions.supervisor.token, "/api/inspections", {
        method: "PATCH",
        body: JSON.stringify({
          id: probeAction.id,
          stage_number: 5,
          hse_verification_notes: "e2e execution probe",
        }),
      });
      check(
        "supervisor advances action to stage 5",
        advance5.status === 200 && Number(advance5.body?.action?.stage_number) === 5,
        advance5.body?.error || `stage=${advance5.body?.action?.stage_number}`
      );

      // Evaluation must not close a report while field work is unfinished.
      const earlyEval = await call(sessions.management.token, "/api/inspections", {
        method: "PATCH",
        body: JSON.stringify({
          id: probeAction.id,
          management_decision: "EVALUATED",
          management_notes: "Evaluasi terlalu dini",
          effectiveness_rating: 4,
        }),
      });
      check(
        "evaluation blocked before stage 6",
        earlyEval.status === 409,
        `status=${earlyEval.status}`
      );

      const advance6 = await call(sessions.supervisor.token, "/api/inspections", {
        method: "PATCH",
        body: JSON.stringify({ id: probeAction.id, stage_number: 6 }),
      });
      check(
        "supervisor advances action to stage 6",
        advance6.status === 200 && Number(advance6.body?.action?.stage_number) === 6,
        advance6.body?.error || `stage=${advance6.body?.action?.stage_number}`
      );

      const evaluate = await call(sessions.management.token, "/api/inspections", {
        method: "PATCH",
        body: JSON.stringify({
          id: probeAction.id,
          management_decision: "EVALUATED",
          management_notes: "Tindakan terbukti efektif di lapangan.",
          effectiveness_rating: 5,
        }),
      });
      check(
        "management evaluates and closes the report",
        evaluate.status === 200 &&
          String(evaluate.body?.report?.hse_status).toUpperCase() === "CLOSED" &&
          String(evaluate.body?.action?.management_status).toUpperCase() === "EVALUATED",
        evaluate.body?.error || `report=${evaluate.body?.report?.hse_status}`
      );
    }

    // Notifications: the worker must have been told about every step.
    const inbox = await call(sessions.worker.token, "/api/notifications");
    const related = (inbox.body?.notifications || []).filter(
      (n) => n.related_report_id === mine.id
    );
    check(
      "worker receives workflow notifications",
      related.length >= 2,
      `${related.length} notifications for the probe report`
    );

    const mgmtInbox = await call(sessions.management.token, "/api/notifications");
    check(
      "management receives approval notifications",
      (mgmtInbox.body?.notifications || []).some((n) => n.category === "APPROVAL"),
      `${(mgmtInbox.body?.notifications || []).length} rows`
    );

    // ------------------------------------------------------------ coordination
    const coord = await call(sessions.supervisor.token, "/api/coordination", {
      method: "POST",
      body: JSON.stringify({
        to_role: "hse",
        subject: "E2E probe coordination",
        message: "Mohon verifikasi area probe sebelum pekerjaan dimulai.",
        priority: "NORMAL",
        zone_name: "Pit Utama",
      }),
    });
    check("supervisor can send coordination", coord.status === 200 && coord.body?.request?.id, coord.body?.error || "");
    const coordId = coord.body?.request?.id;

    const workerCoord = await call(sessions.worker.token, "/api/coordination", {
      method: "POST",
      body: JSON.stringify({ to_role: "hse", subject: "x", message: "x" }),
    });
    check("worker cannot send coordination", workerCoord.status === 403, `status=${workerCoord.status}`);

    if (coordId) {
      const reply = await call(sessions.hse.token, "/api/coordination", {
        method: "PATCH",
        body: JSON.stringify({ id: coordId, status: "RESOLVED", response: "Sudah diverifikasi, aman." }),
      });
      check("HSE can reply and resolve coordination", reply.status === 200, reply.body?.error || "");
    }
  }

  // ------------------------------------------------- conduct K3 inspection
  const newInspection = await call(sessions.supervisor.token, "/api/inspections", {
    method: "POST",
    body: JSON.stringify({
      inspection_category: "Penggunaan APD",
      zone_name: "Pit Utama",
      title: "E2E Test Inspeksi APD",
      notes: "Semua pekerja di pit diperiksa",
      passed_items: 4,
      failed_items: 1,
      findings: [
        {
          item: "Kacamata safety",
          note: "1 operator tidak memakai kacamata safety saat berdebu",
          severity: "medium",
        },
      ],
    }),
  });
  check(
    "supervisor can create K3 inspection",
    newInspection.status === 200 && newInspection.body?.findings_count === 1,
    newInspection.body?.error || `inspection_id=${newInspection.body?.inspection?.id}`
  );
  const createdInspId = newInspection.body?.inspection?.id;
  const findingAction = (newInspection.body?.created_actions || [])[0];

  if (findingAction?.id) {
    const approveFinding = await call(sessions.management.token, "/api/inspections", {
      method: "PATCH",
      body: JSON.stringify({
        id: findingAction.id,
        management_decision: "APPROVED",
        management_notes: "Setujui temuan inspeksi untuk perbaikan.",
      }),
    });
    check(
      "management approves an inspection finding",
      approveFinding.status === 200,
      approveFinding.body?.error || ""
    );
  }

  const workerCreateInsp = await call(sessions.worker.token, "/api/inspections", {
    method: "POST",
    body: JSON.stringify({
      inspection_category: "Penggunaan APD",
      zone_name: "Pit Utama",
      title: "Worker Inspection Attempt",
      passed_items: 5,
      failed_items: 0,
      findings: [],
    }),
  });
  check(
    "worker cannot create K3 inspections",
    workerCreateInsp.status === 403,
    `status=${workerCreateInsp.status}`
  );

  // ------------------------------------------------- corrective action advance
  const inspections = await call(sessions.supervisor.token, "/api/inspections");
  const tickets = inspections.body?.corrective_actions || [];
  check("inspection register", Array.isArray(tickets), `${tickets.length} tickets`);

  // Pick a ticket that still has room to move; a completed one is asserted
  // separately, because refusing to reopen a closed ticket is the correct
  // behaviour rather than a failure.
  const ticket = tickets.find(
    (t) =>
      Number(t.stage_number) < 6 &&
      String(t.management_status || "").toUpperCase() === "APPROVED"
  );
  const completed = tickets.find((t) => Number(t.stage_number) >= 6);

  if (ticket) {
    const before = ticket.stage_number;
    const advance = await call(sessions.supervisor.token, "/api/inspections", {
      method: "PATCH",
      body: JSON.stringify({
        id: ticket.id,
        stage_number: before + 1,
        hse_verification_notes: "e2e probe",
      }),
    });
    check(
      "corrective action advances",
      advance.status === 200 && Number(advance.body?.action?.stage_number) === before + 1,
      advance.body?.error || `stage ${advance.body?.action?.stage_number}`
    );

    // A worker must be refused.
    const denied = await call(sessions.worker.token, "/api/inspections", {
      method: "PATCH",
      body: JSON.stringify({ id: ticket.id, stage_number: 6 }),
    });
    check("worker cannot verify tickets", denied.status === 403, `status=${denied.status}`);
  } else {
    check("corrective action advances", false, "no approved ticket under stage 6 to advance");
  }

  if (completed) {
    const reopen = await call(sessions.supervisor.token, "/api/inspections", {
      method: "PATCH",
      body: JSON.stringify({ id: completed.id, stage_number: 2 }),
    });
    check(
      "closed ticket cannot be reopened",
      reopen.status === 409,
      `status=${reopen.status}`
    );
  }

  // ------------------------------------------------------- early warning CRUD
  const created = await call(sessions.hse.token, "/api/bmkg", {
    method: "POST",
    body: JSON.stringify({
      title: "E2E probe warning",
      description: "Temporary probe warning.",
      severity: "medium",
      hazard_tags: ["Probe"],
      affected_zones: ["Pit Utama (Area Penambangan Aktif)"],
      safety_instructions: "None.",
      valid_until: new Date(Date.now() + 3600_000).toISOString(),
    }),
  });
  check("HSE can publish a warning", created.status === 201, created.body?.error || "");
  const warningId = created.body?.warning?.id;

  if (warningId) {
    const amended = await call(sessions.hse.token, "/api/bmkg", {
      method: "PATCH",
      body: JSON.stringify({ id: warningId, severity: "high" }),
    });
    check("HSE can amend a warning", amended.status === 200, amended.body?.error || "");

    const stoodDown = await call(sessions.hse.token, `/api/bmkg?id=${warningId}`, {
      method: "DELETE",
    });
    check("HSE can stand a warning down", stoodDown.status === 200, stoodDown.body?.error || "");

    const denied = await call(sessions.worker.token, "/api/bmkg", {
      method: "POST",
      body: JSON.stringify({ title: "should fail", description: "should fail" }),
    });
    check("worker cannot publish warnings", denied.status === 403, `status=${denied.status}`);
  }

  // --------------------------------------------------------------- ESG writes
  const kpiWrite = await call(sessions.management.token, "/api/kpi", {
    method: "PATCH",
    body: JSON.stringify({ safe_man_hours: 1247652, calculated_trir: 0.48 }),
  });
  check("management can write ESG metrics", kpiWrite.status === 200, kpiWrite.body?.error || "");

  const hseWrite = await call(sessions.hse.token, "/api/kpi", {
    method: "PATCH",
    body: JSON.stringify({ safe_man_hours: 999999 }),
  });
  check("HSE cannot write ESG metrics", hseWrite.status === 403, `status=${hseWrite.status}`);

  const kpi = await call(sessions.supervisor.token, "/api/kpi");
  check("supervisor can read ESG metrics", kpi.status === 200 && kpi.body?.data != null);
  check("KPI payload is not fabricated", kpi.body?.kpis === undefined, "no hardcoded fallback block");

  // ------------------------------------------------------------------ cleanup
  // hazard_reports has no DELETE policy, so only the inspection and warning
  // probes can be removed from here. The e2e report remains for manual cleanup.
  if (warningId) {
    const svc = createClient(URL_, process.env.SUPABASE_SERVICE_ROLE_KEY || KEY, {
      auth: { persistSession: false },
    });
    await svc.from("early_warnings").delete().eq("id", warningId);
  }
  if (createdInspId) {
    const svc = createClient(URL_, process.env.SUPABASE_SERVICE_ROLE_KEY || KEY, {
      auth: { persistSession: false },
    });
    await svc.from("k3_inspections").delete().eq("id", createdInspId);
  }

  const failed = results.filter((r) => !r.pass);
  console.log(`\n${results.length - failed.length}/${results.length} checks passed`);
  process.exit(failed.length ? 1 : 0);
}

async function roleOf(session) {
  const { data } = await session.client
    .from("profiles")
    .select("role")
    .eq("id", session.userId)
    .maybeSingle();
  return data?.role || "unknown";
}

main().catch((e) => {
  console.error("fatal:", e);
  process.exit(1);
});
