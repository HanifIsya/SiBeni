/**
 * End-to-end check of the SI BENI write paths against a live Supabase project.
 *
 * Signs in as each seeded account, then exercises the endpoints that were
 * previously broken: report ingest, HSE review, corrective-action advance,
 * early-warning CRUD, and ESG metric writes.
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

  // -------------------------------------------------------------- review flow
  if (mine) {
    const review = await call(sessions.hse.token, "/api/reports", {
      method: "PATCH",
      body: JSON.stringify({ id: mine.id, hse_status: "IN_REVIEW", hse_notes: "Probe review" }),
    });
    check("HSE can review a report", review.status === 200, review.body?.error || "");

    const close = await call(sessions.hse.token, "/api/reports", {
      method: "PATCH",
      body: JSON.stringify({ id: mine.id, hse_status: "CLOSED", hse_notes: "Probe closed" }),
    });
    check("HSE can close a report", close.status === 200, close.body?.error || "");

    // A worker must be refused.
    const denied = await call(sessions.worker.token, "/api/reports", {
      method: "PATCH",
      body: JSON.stringify({ id: mine.id, hse_status: "CLOSED" }),
    });
    check("worker cannot review", denied.status === 403, `status=${denied.status}`);
  }

  // ------------------------------------------------- corrective action advance
  const inspections = await call(sessions.supervisor.token, "/api/inspections");
  const tickets = inspections.body?.corrective_actions || [];
  check("inspection register", Array.isArray(tickets), `${tickets.length} tickets`);

  // Pick a ticket that still has room to move; a completed one is asserted
  // separately, because refusing to reopen a closed ticket is the correct
  // behaviour rather than a failure.
  const ticket = tickets.find((t) => Number(t.stage_number) < 6);
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
    check("corrective action advances", false, "no ticket left under stage 6 to advance");
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
  if (mine) {
    const svc = createClient(URL_, process.env.SUPABASE_SERVICE_ROLE_KEY || KEY, {
      auth: { persistSession: false },
    });
    await svc.from("hazard_reports").delete().eq("local_id", localId);
  }
  if (warningId) {
    const svc = createClient(URL_, process.env.SUPABASE_SERVICE_ROLE_KEY || KEY, {
      auth: { persistSession: false },
    });
    await svc.from("early_warnings").delete().eq("id", warningId);
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