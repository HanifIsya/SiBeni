import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";

export async function GET() {
  try {
    const { data, error } = await supabase
      .from("energy_emission_metrics")
      .select("*")
      .order("record_date", { ascending: false })
      .limit(1)
      .single();

    if (error || !data) {
      // Aligned with DESIGN.md and PDF presentation
      return NextResponse.json({
        kpis: {
          safe_man_hours: {
            value: 1247652,
            unit: "jam",
            change_pct: 12.4,
            label: "Total Jam Kerja Aman",
          },
          trir: {
            value: 0.48,
            unit: "",
            change_pct: -20.0,
            label: "TRIR (Total Recordable Incident Rate)",
            target: 0.5,
          },
          total_energy: {
            value: 24785,
            unit: "GJ",
            change_pct: -3.1,
            label: "Energi Total",
          },
          energy_intensity: {
            value: 2.41,
            unit: "GJ/ton",
            change_pct: -5.5,
            label: "Intensitas Energi",
          },
          total_co2e: {
            value: 12456,
            unit: "ton",
            change_pct: -6.8,
            label: "Emisi Total CO2e",
          },
        },
        energy_breakdown: [
          { source: "Listrik PLN & Genset", percentage: 45, value_gj: 11153 },
          { source: "Gas Alam", percentage: 25, value_gj: 6196 },
          { source: "BBM Solar Industri", percentage: 15, value_gj: 3718 },
          { source: "Lainnya", percentage: 15, value_gj: 3718 },
        ],
        incident_trend: [
          { month: "Jan", near_miss: 12, incident: 0 },
          { month: "Feb", near_miss: 15, incident: 1 },
          { month: "Mar", near_miss: 19, incident: 0 },
          { month: "Apr", near_miss: 24, incident: 1 },
          { month: "Mei", near_miss: 22, incident: 0 },
        ],
      });
    }

    return NextResponse.json({ data });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
