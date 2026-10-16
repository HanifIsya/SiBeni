import { NextRequest, NextResponse } from "next/server";
import { getUserClient } from "@/lib/supabase";
import { resolveProfile } from "@/lib/auth";

export const dynamic = "force-dynamic";

const NUMERIC_FIELDS = [
  "safe_man_hours",
  "total_recordable_incidents",
  "calculated_trir",
  "energy_electricity_gj",
  "energy_natural_gas_gj",
  "energy_diesel_fuel_gj",
  "energy_other_gj",
  "total_energy_gj",
  "material_hauled_ton",
  "energy_intensity_gj_per_ton",
  "total_co2e_emissions_ton",
];

/**
 * GET /api/kpi
 *
 * K3, energy and carbon metrics.
 *
 * There is deliberately NO fallback payload here. The previous implementation
 * returned a hardcoded "kpis" block when the table was empty, which meant the
 * dashboard could show confident numbers that nobody had actually measured.
 * An empty response is now the honest answer.
 */
export async function GET(req: NextRequest) {
  try {
    const client = getUserClient(req);
    const { data, error } = await client
      .from("energy_emission_metrics")
      .select("*")
      .order("record_date", { ascending: false })
      .limit(12);

    if (error) throw error;

    const history = data ?? [];

    // Derive the energy split from the latest period only; the shares must
    // always add up to the reported total rather than to invented percentages.
    const latest = history[0] ?? null;
    let breakdown: any[] = [];
    if (latest) {
      const parts = [
        { source: "Listrik & genset", value: latest.energy_electricity_gj, color: "brand" },
        { source: "Gas alam", value: latest.energy_natural_gas_gj, color: "accent" },
        { source: "BBM solar", value: latest.energy_diesel_fuel_gj, color: "amber" },
        { source: "Lainnya", value: latest.energy_other_gj, color: "muted" },
      ];
      const total =
        parts.reduce((acc, p) => acc + Number(p.value || 0), 0) || 0;
      breakdown = parts.map((p) => ({
        source: p.source,
        color: p.color,
        value_gj: Number(p.value || 0),
        share: total > 0 ? Number((Number(p.value || 0) / total) * 100).toFixed(1) : 0,
      }));
    }

    return NextResponse.json({
      data: latest,
      history,
      energy_breakdown: breakdown,
      has_data: Boolean(latest),
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

/**
 * PATCH /api/kpi
 *
 * Upserts one reporting period. RLS restricts writes to hse / management; the
 * client additionally gates the edit affordance to management.
 */
export async function PATCH(req: NextRequest) {
  try {
    const body = await req.json();
    const profile = await resolveProfile(req);
    if (!profile) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

    const recordDate: string = body.record_date || new Date().toISOString().slice(0, 10);

    const payload: Record<string, unknown> = {
      record_date: recordDate,
      updated_at: new Date().toISOString(),
    };

    for (const field of NUMERIC_FIELDS) {
      if (body[field] !== undefined && body[field] !== null && body[field] !== "") {
        const parsed = Number(body[field]);
        if (Number.isFinite(parsed)) payload[field] = parsed;
      }
    }

    if (Object.keys(payload).length <= 2) {
      return NextResponse.json(
        { error: "Tidak ada metrik yang dikirim." },
        { status: 400 }
      );
    }

    const client = getUserClient(req);
    const { data, error } = await client
      .from("energy_emission_metrics")
      .upsert(payload, { onConflict: "record_date" })
      .select()
      .single();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 403 });
    }

    return NextResponse.json({
      message: "Metrik K3 & ESG berhasil disimpan.",
      data,
      updated_by: profile.full_name,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}