"use client";

import React, { useState } from "react";
import {
  ShieldAlert,
  Flame,
  Activity,
  Zap,
  Leaf,
  Clock,
  AlertTriangle,
  Radio,
  MapPin,
  CheckCircle2,
  TrendingDown,
  TrendingUp,
  BarChart3,
  Calendar,
  Layers,
  ChevronRight,
  RefreshCw,
  Bell,
  HardHat,
} from "lucide-react";

export default function DashboardPage() {
  const [activeTab, setActiveTab] = useState("dashboard");
  const [selectedZone, setSelectedZone] = useState("Semua Lokasi");

  const zones = [
    { name: "Pit Utama", risk: "high", hazard: "Potensi Longsor Lereng Barat", color: "bg-orange-500", border: "border-orange-500", text: "text-orange-600", bgLight: "bg-orange-50" },
    { name: "Jalan Angkut KM 0-15", risk: "medium", hazard: "Debu Tebal & Blind Spot KM 4.2", color: "bg-yellow-500", border: "border-yellow-500", text: "text-yellow-600", bgLight: "bg-yellow-50" },
    { name: "Stockpile & ROM", risk: "low", hazard: "Operasi Normal Terkendali", color: "bg-green-600", border: "border-green-600", text: "text-green-600", bgLight: "bg-green-50" },
    { name: "Workshop Alat Berat", risk: "medium", hazard: "Perbaikan Bay 3 (Hot Work)", color: "bg-yellow-500", border: "border-yellow-500", text: "text-yellow-600", bgLight: "bg-yellow-50" },
    { name: "Fasilitas Pengolahan", risk: "high", hazard: "Getaran & Bising Crusher #2", color: "bg-orange-500", border: "border-orange-500", text: "text-orange-600", bgLight: "bg-orange-50" },
    { name: "Gudang Logistik & Handak", risk: "low", hazard: "Aman Terisolasi Ring 1", color: "bg-green-600", border: "border-green-600", text: "text-green-600", bgLight: "bg-green-50" },
    { name: "Fasilitas Pendukung", risk: "low", hazard: "Klinik & Mess Siaga", color: "bg-green-600", border: "border-green-600", text: "text-green-600", bgLight: "bg-green-50" },
  ];

  return (
    <div className="flex h-screen overflow-hidden bg-[#F8FAFC]">
      {/* 1. SIDEBAR (Dark Slate #0B192C) */}
      <aside className="w-64 bg-[#0B192C] text-slate-300 flex flex-col justify-between p-4 shrink-0 shadow-xl">
        <div>
          {/* Logo & Org */}
          <div className="flex items-center gap-3 px-2 py-3 mb-6 border-b border-slate-800">
            <div className="w-10 h-10 rounded-lg bg-[#0F4C81] flex items-center justify-center text-cyan-400 font-bold border border-cyan-500/30">
              <HardHat className="w-6 h-6 text-cyan-400" />
            </div>
            <div>
              <h1 className="text-white font-extrabold text-base tracking-wide flex items-center gap-1.5">
                SI BENI <span className="text-[10px] bg-cyan-500/20 text-cyan-300 px-1.5 py-0.5 rounded border border-cyan-500/30">K3</span>
              </h1>
              <p className="text-[11px] text-slate-400 font-medium">PT Consnet Mining</p>
            </div>
          </div>

          {/* Nav Items */}
          <nav className="space-y-1.5">
            <button
              onClick={() => setActiveTab("dashboard")}
              className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-semibold transition ${
                activeTab === "dashboard"
                  ? "bg-[#15803D] text-white shadow"
                  : "hover:bg-slate-800/60 text-slate-300"
              }`}
            >
              <BarChart3 className="w-4 h-4" />
              <span>Dashboard Terpadu</span>
            </button>

            <button
              onClick={() => setActiveTab("risk-map")}
              className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-semibold transition ${
                activeTab === "risk-map"
                  ? "bg-[#15803D] text-white shadow"
                  : "hover:bg-slate-800/60 text-slate-300"
              }`}
            >
              <MapPin className="w-4 h-4" />
              <span>Peta Risiko 7 Zona</span>
            </button>

            <button
              onClick={() => setActiveTab("inspections")}
              className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-semibold transition ${
                activeTab === "inspections"
                  ? "bg-[#15803D] text-white shadow"
                  : "hover:bg-slate-800/60 text-slate-300"
              }`}
            >
              <CheckCircle2 className="w-4 h-4" />
              <span>Inspeksi & Corrective Action</span>
            </button>

            <button
              onClick={() => setActiveTab("emergency")}
              className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-semibold transition ${
                activeTab === "emergency"
                  ? "bg-[#DC2626] text-white shadow"
                  : "hover:bg-slate-800/60 text-slate-300"
              }`}
            >
              <ShieldAlert className="w-4 h-4 text-red-400" />
              <span>Pusat Tanggap Darurat</span>
            </button>
          </nav>
        </div>

        {/* System & Connectivity Status */}
        <div className="bg-slate-900/90 rounded-lg p-3 border border-slate-800">
          <div className="flex items-center justify-between text-xs mb-1.5">
            <span className="text-slate-400 font-medium">Status Integrasi</span>
            <span className="flex items-center gap-1 text-emerald-400 font-bold">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
              Aktif
            </span>
          </div>
          <p className="text-[11px] text-slate-400">BMKG Radar: Wilayah IV</p>
          <p className="text-[11px] text-slate-400">Database: Supabase Connected</p>
        </div>
      </aside>

      {/* 2. MAIN CONTENT AREA */}
      <main className="flex-1 flex flex-col overflow-y-auto">
        {/* Top Header */}
        <header className="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between sticky top-0 z-20 shadow-sm">
          <div>
            <div className="flex items-center gap-2">
              <span className="text-xs font-bold text-[#0F4C81] tracking-wider uppercase">Executive HSE Console</span>
              <span className="text-slate-300">•</span>
              <span className="text-xs text-slate-500 font-mono">Platform v1.0.0</span>
            </div>
            <h2 className="text-xl font-extrabold text-slate-900">Dashboard K3, Energi & Emisi Karbon</h2>
          </div>

          <div className="flex items-center gap-3">
            {/* Filter Date */}
            <div className="flex items-center gap-2 bg-slate-100 px-3 py-2 rounded-lg border border-slate-300 text-xs font-semibold text-slate-700">
              <Calendar className="w-3.5 h-3.5 text-slate-500" />
              <span>Periode: 1 - 31 Oktober 2026</span>
            </div>

            {/* Filter Location */}
            <select
              value={selectedZone}
              onChange={(e) => setSelectedZone(e.target.value)}
              className="bg-white border border-slate-300 text-xs font-semibold text-slate-800 px-3 py-2 rounded-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-[#0F4C81]"
            >
              <option>Semua Lokasi</option>
              <option>Pit Utama</option>
              <option>Jalan Angkut KM 0-15</option>
              <option>Stockpile</option>
              <option>Workshop</option>
              <option>Fasilitas Pengolahan</option>
            </select>

            <button className="p-2 rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-50">
              <Bell className="w-4 h-4" />
            </button>
          </div>
        </header>

        {/* Content Body */}
        <div className="p-6 space-y-6 max-w-7xl">
          {/* Active Early Warning Banner */}
          <div className="bg-gradient-to-r from-orange-50 to-amber-50 border-l-4 border-orange-500 p-4 rounded-r-lg shadow-sm flex items-start justify-between">
            <div className="flex items-start gap-3">
              <div className="p-2 bg-orange-100 rounded-lg text-orange-600 mt-0.5">
                <AlertTriangle className="w-5 h-5" />
              </div>
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <span className="bg-orange-600 text-white text-[10px] font-bold px-2 py-0.5 rounded uppercase">
                    Peringatan Dini BMKG
                  </span>
                  <span className="text-xs font-semibold text-orange-900">Status: SIAGA (Periode 07:00 - 19:00 WIB)</span>
                </div>
                <h3 className="text-sm font-bold text-slate-900">
                  Waspada Hujan Lebat Disertai Angin Kencang & Potensi Longsor Lereng Barat
                </h3>
                <p className="text-xs text-slate-600 mt-1">
                  Zona Terdampak: <strong>Pit Utama, Haul Road KM 4.2, Stockpile</strong>. Batasi kecepatan kendaraan angkut maks 25 km/jam.
                </p>
              </div>
            </div>
            <button className="shrink-0 bg-[#0F4C81] hover:bg-[#0c3c66] text-white text-xs font-bold px-4 py-2 rounded-lg shadow">
              Lihat Panduan SOP
            </button>
          </div>

          {/* 5 KPI Cards Row */}
          <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
            {/* KPI 1: Safe Man-Hours */}
            <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm hover:shadow transition">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-semibold text-slate-500">Jam Kerja Aman</span>
                <Clock className="w-4 h-4 text-[#0F4C81]" />
              </div>
              <div className="text-2xl font-black font-mono text-slate-900">1.247.652</div>
              <div className="flex items-center gap-1 text-[11px] font-bold text-emerald-600 mt-2">
                <TrendingUp className="w-3.5 h-3.5" />
                <span>+12,4% vs bulan lalu</span>
              </div>
            </div>

            {/* KPI 2: TRIR */}
            <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm hover:shadow transition">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-semibold text-slate-500">TRIR (Insiden Rate)</span>
                <Activity className="w-4 h-4 text-emerald-600" />
              </div>
              <div className="text-2xl font-black font-mono text-slate-900">0,48</div>
              <div className="flex items-center gap-1 text-[11px] font-bold text-emerald-600 mt-2">
                <TrendingDown className="w-3.5 h-3.5" />
                <span>-20,0% (Target: &lt; 0,50)</span>
              </div>
            </div>

            {/* KPI 3: Total Energi */}
            <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm hover:shadow transition">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-semibold text-slate-500">Energi Total</span>
                <Zap className="w-4 h-4 text-amber-500" />
              </div>
              <div className="text-2xl font-black font-mono text-slate-900">24.785 <span className="text-sm font-normal text-slate-500">GJ</span></div>
              <div className="flex items-center gap-1 text-[11px] font-bold text-emerald-600 mt-2">
                <TrendingDown className="w-3.5 h-3.5" />
                <span>-3,1% efisiensi</span>
              </div>
            </div>

            {/* KPI 4: Intensitas Energi */}
            <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm hover:shadow transition">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-semibold text-slate-500">Intensitas Energi</span>
                <BarChart3 className="w-4 h-4 text-blue-500" />
              </div>
              <div className="text-2xl font-black font-mono text-slate-900">2,41 <span className="text-sm font-normal text-slate-500">GJ/t</span></div>
              <div className="flex items-center gap-1 text-[11px] font-bold text-emerald-600 mt-2">
                <TrendingDown className="w-3.5 h-3.5" />
                <span>-5,5% per ton angkut</span>
              </div>
            </div>

            {/* KPI 5: Total Emisi CO2e */}
            <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm hover:shadow transition">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-semibold text-slate-500">Emisi Total CO₂e</span>
                <Leaf className="w-4 h-4 text-emerald-600" />
              </div>
              <div className="text-2xl font-black font-mono text-slate-900">12.456 <span className="text-sm font-normal text-slate-500">ton</span></div>
              <div className="flex items-center gap-1 text-[11px] font-bold text-emerald-600 mt-2">
                <TrendingDown className="w-3.5 h-3.5" />
                <span>-6,8% dekarbonisasi</span>
              </div>
            </div>
          </div>

          {/* Charts Row */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Chart 1: K3 Tren Insiden & Near Miss */}
            <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h4 className="text-sm font-bold text-slate-900">K3 — Tren Pelaporan & Insiden</h4>
                  <p className="text-[11px] text-slate-500">Near Miss aktif vs Target Insiden Nol</p>
                </div>
                <span className="text-xs bg-emerald-100 text-emerald-800 font-bold px-2 py-0.5 rounded">
                  Zero Fatal
                </span>
              </div>
              <div className="h-44 flex items-end justify-between gap-3 pt-6 border-b border-slate-100">
                {[
                  { m: "Jan", nm: 12, inc: 0 },
                  { m: "Feb", nm: 15, inc: 1 },
                  { m: "Mar", nm: 19, inc: 0 },
                  { m: "Apr", nm: 24, inc: 1 },
                  { m: "Mei", nm: 22, inc: 0 },
                  { m: "Jun", nm: 28, inc: 0 },
                ].map((item, idx) => (
                  <div key={idx} className="flex-1 flex flex-col items-center gap-1">
                    <div className="w-full flex items-end justify-center gap-1 h-32">
                      <div
                        style={{ height: `${item.nm * 3.5}px` }}
                        className="w-1/2 bg-[#00B4D8] rounded-t-sm hover:opacity-80 transition"
                        title={`Near Miss: ${item.nm}`}
                      ></div>
                      <div
                        style={{ height: `${item.inc * 30}px` }}
                        className="w-1/2 bg-red-500 rounded-t-sm"
                        title={`Insiden: ${item.inc}`}
                      ></div>
                    </div>
                    <span className="text-[11px] font-semibold text-slate-500">{item.m}</span>
                  </div>
                ))}
              </div>
              <div className="flex items-center justify-center gap-6 mt-3 text-xs text-slate-600">
                <span className="flex items-center gap-1.5 font-medium">
                  <span className="w-2.5 h-2.5 bg-[#00B4D8] rounded-sm"></span> Laporan Near Miss
                </span>
                <span className="flex items-center gap-1.5 font-medium">
                  <span className="w-2.5 h-2.5 bg-red-500 rounded-sm"></span> Insiden Aktual
                </span>
              </div>
            </div>

            {/* Chart 2: Konsumsi Energi per Sumber */}
            <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h4 className="text-sm font-bold text-slate-900">Energi — Konsumsi per Sumber</h4>
                  <p className="text-[11px] text-slate-500">Total: 24.785 GJ</p>
                </div>
                <Zap className="w-4 h-4 text-amber-500" />
              </div>
              <div className="space-y-3 pt-2">
                <div>
                  <div className="flex justify-between text-xs font-semibold mb-1">
                    <span className="text-slate-700">Listrik PLN & Site Genset</span>
                    <span className="font-mono text-slate-900">45% (11.153 GJ)</span>
                  </div>
                  <div className="w-full bg-slate-100 h-2.5 rounded-full overflow-hidden">
                    <div className="bg-[#0F4C81] h-full rounded-full" style={{ width: "45%" }}></div>
                  </div>
                </div>

                <div>
                  <div className="flex justify-between text-xs font-semibold mb-1">
                    <span className="text-slate-700">Gas Alam Operasional</span>
                    <span className="font-mono text-slate-900">25% (6.196 GJ)</span>
                  </div>
                  <div className="w-full bg-slate-100 h-2.5 rounded-full overflow-hidden">
                    <div className="bg-[#00B4D8] h-full rounded-full" style={{ width: "25%" }}></div>
                  </div>
                </div>

                <div>
                  <div className="flex justify-between text-xs font-semibold mb-1">
                    <span className="text-slate-700">BBM Solar Industri (Hauler)</span>
                    <span className="font-mono text-slate-900">15% (3.718 GJ)</span>
                  </div>
                  <div className="w-full bg-slate-100 h-2.5 rounded-full overflow-hidden">
                    <div className="bg-amber-500 h-full rounded-full" style={{ width: "15%" }}></div>
                  </div>
                </div>

                <div>
                  <div className="flex justify-between text-xs font-semibold mb-1">
                    <span className="text-slate-700">Lainnya / Pelumas Mesin</span>
                    <span className="font-mono text-slate-900">15% (3.718 GJ)</span>
                  </div>
                  <div className="w-full bg-slate-100 h-2.5 rounded-full overflow-hidden">
                    <div className="bg-slate-400 h-full rounded-full" style={{ width: "15%" }}></div>
                  </div>
                </div>
              </div>
            </div>

            {/* Chart 3: Tren Emisi Karbon (CO2e) */}
            <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h4 className="text-sm font-bold text-slate-900">Emisi — Tren Emisi Karbon</h4>
                  <p className="text-[11px] text-slate-500">Target penurunan 10% yoy</p>
                </div>
                <Leaf className="w-4 h-4 text-emerald-600" />
              </div>
              <div className="h-44 flex items-end justify-between gap-3 pt-6 border-b border-slate-100">
                {[
                  { m: "Jan", val: 14.2 },
                  { m: "Feb", val: 13.8 },
                  { m: "Mar", val: 13.1 },
                  { m: "Apr", val: 12.8 },
                  { m: "Mei", val: 12.45 },
                ].map((item, idx) => (
                  <div key={idx} className="flex-1 flex flex-col items-center gap-1">
                    <div className="w-full flex items-end justify-center h-32">
                      <div
                        style={{ height: `${item.val * 8}px` }}
                        className="w-full max-w-[28px] bg-gradient-to-t from-emerald-600 to-emerald-400 rounded-t-sm"
                        title={`${item.val}k ton`}
                      ></div>
                    </div>
                    <span className="text-[11px] font-semibold text-slate-500">{item.m}</span>
                  </div>
                ))}
              </div>
              <div className="flex items-center justify-between mt-3 text-xs text-slate-600">
                <span className="font-medium text-emerald-700">Progres: Berhasil mereduksi 1.744 ton CO₂e</span>
                <span className="font-bold text-slate-900 font-mono">12.456 ton</span>
              </div>
            </div>
          </div>

          {/* Mining Zones Overview Table */}
          <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
            <div className="px-5 py-4 border-b border-slate-200 flex items-center justify-between">
              <div>
                <h4 className="text-sm font-bold text-slate-900">Status K3 & Tingkat Risiko 7 Zona Operasional Tambang</h4>
                <p className="text-xs text-slate-500">Diperbarui real-time via telemetri lapangan & laporan mobile SI BENI</p>
              </div>
              <span className="text-xs font-semibold text-[#0F4C81] flex items-center gap-1">
                <RefreshCw className="w-3.5 h-3.5" /> Auto-sync aktif
              </span>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-50 text-slate-600 uppercase font-bold tracking-wider border-b border-slate-200">
                  <tr>
                    <th className="px-5 py-3">Zona Kerja Tambang</th>
                    <th className="px-5 py-3">Tingkat Risiko (4-Tier)</th>
                    <th className="px-5 py-3">Potensi Bahaya Teridentifikasi</th>
                    <th className="px-5 py-3">Titik Kumpul (Assembly Point)</th>
                    <th className="px-5 py-3 text-right">Aksi</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {zones.map((zone, idx) => (
                    <tr key={idx} className="hover:bg-slate-50/80 transition">
                      <td className="px-5 py-3.5 font-bold text-slate-900 flex items-center gap-2">
                        <span className={`w-2 h-2 rounded-full ${zone.color}`}></span>
                        {zone.name}
                      </td>
                      <td className="px-5 py-3.5">
                        <span className={`px-2.5 py-1 rounded-full font-bold uppercase text-[10px] ${zone.bgLight} ${zone.text} border ${zone.border}`}>
                          {zone.risk === "critical" ? "Sangat Tinggi" : zone.risk === "high" ? "Tinggi" : zone.risk === "medium" ? "Sedang" : "Rendah"}
                        </span>
                      </td>
                      <td className="px-5 py-3.5 text-slate-700 font-medium">
                        {zone.hazard}
                      </td>
                      <td className="px-5 py-3.5 text-slate-600">
                        Titik Kumpul {String.fromCharCode(65 + idx)} (Zona Aman Terdekat)
                      </td>
                      <td className="px-5 py-3.5 text-right">
                        <button className="text-[#0F4C81] hover:underline font-bold inline-flex items-center gap-1">
                          Detail <ChevronRight className="w-3.5 h-3.5" />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
