import { NextRequest, NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const { data: correctiveActions, error: caError } = await supabase
      .from("corrective_actions")
      .select("*")
      .order("created_at", { ascending: false });

    if (caError) {
      return NextResponse.json({ error: caError.message }, { status: 500 });
    }

    const { data: inspections, error: inspError } = await supabase
      .from("k3_inspections")
      .select("*")
      .order("created_at", { ascending: false });

    return NextResponse.json({
      corrective_actions: correctiveActions || [],
      inspections: inspections || [],
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

export async function PATCH(req: NextRequest) {
  try {
    const body = await req.json();
    const { id, status, stage_number, hse_verification_notes } = body;

    if (!id) {
      return NextResponse.json({ error: "Missing corrective action id" }, { status: 400 });
    }

    const updatePayload: any = { updated_at: new Date().toISOString() };
    if (status) updatePayload.status = status;
    if (stage_number) updatePayload.stage_number = stage_number;
    if (hse_verification_notes) updatePayload.hse_verification_notes = hse_verification_notes;

    const { data, error } = await supabase
      .from("corrective_actions")
      .update(updatePayload)
      .eq("id", id)
      .select()
      .single();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ message: "Corrective action berhasil diperbarui", action: data });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
