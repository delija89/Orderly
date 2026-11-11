import type { Metadata } from "next";
import { Geist } from "next/font/google";
import "./globals.css";

const geist = Geist({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Orderly",
  description: "Multi-Store Order Command Center",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en">
      {/* geist.className (NOT geist.variable) — otherwise font is not applied */}
      <body className={geist.className}>{children}</body>
    </html>
  );
}
