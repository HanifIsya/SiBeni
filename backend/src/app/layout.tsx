import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "SI BENI — Dashboard K3, Energi & Emisi | PT Consnet Mining",
  description: "Executive Safety, Hazard & ESG Dashboard for Industrial Mining",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="id">
      <body className="antialiased min-h-screen bg-[#F8FAFC]">
        {children}
      </body>
    </html>
  );
}
