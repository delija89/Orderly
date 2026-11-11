// Temporary design-system test page (step 0.2 + 0.3).
// Verifies brand tokens, Geist font, base styles and the shadcn/Base UI
// component library. Replaced by the real dashboard in Faza 1.

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";

const brandColors = [
  { name: "accent", fg: "var(--brand-accent)", bg: "var(--brand-accent-bg)" },
  { name: "success", fg: "var(--success)", bg: "var(--success-bg)" },
  { name: "warning", fg: "var(--warning)", bg: "var(--warning-bg)" },
  { name: "danger", fg: "var(--danger)", bg: "var(--danger-bg)" },
  { name: "neutral", fg: "var(--neutral)", bg: "var(--neutral-bg)" },
];

export default function Home() {
  return (
    <main className="mx-auto max-w-3xl px-4 py-10">
      <p className="text-label text-muted-foreground">Orderly · Dizajn sistem</p>
      <h1 className="text-h1 mt-1">Tailwind v4 + brend tokeni rade</h1>
      <p className="text-body text-muted-foreground mt-2">
        Font je Geist. Ispod su brend boje, tipografska skala i kartica sa
        senkom i hover tranzicijom.
      </p>

      {/* Brand colors */}
      <section className="mt-8 grid grid-cols-2 gap-3 sm:grid-cols-5">
        {brandColors.map((c) => (
          <div
            key={c.name}
            className="rounded-lg border p-3"
            style={{ borderColor: "var(--border)" }}
          >
            <div
              className="mb-2 h-12 w-full rounded-md"
              style={{ backgroundColor: c.fg }}
            />
            <div
              className="h-6 w-full rounded-md"
              style={{ backgroundColor: c.bg }}
            />
            <p className="text-label mt-2">{c.name}</p>
          </div>
        ))}
      </section>

      {/* Card with shadow + hover lift */}
      <section className="mt-8">
        <div
          className="rounded-xl border bg-card p-5 shadow-md transition-transform hover:-translate-y-px"
          style={{ transitionDuration: "180ms" }}
        >
          <p className="text-label text-muted-foreground">Ukupan prihod</p>
          <p className="text-kpi mt-1" style={{ color: "var(--brand-accent)" }}>
            €12.480
          </p>
          <p className="text-body text-muted-foreground mt-1">
            Kartica: hover za podizanje + senku.
          </p>
        </div>
      </section>

      {/* Typography scale */}
      <section className="mt-8 space-y-1">
        <p className="text-kpi">KPI 32 / 700</p>
        <p className="text-h1">H1 24 / 700</p>
        <p className="text-card-title">Naslov kartice 13 / 600</p>
        <p className="text-body">Body 13 / 400</p>
        <p className="text-label text-muted-foreground">Label 11 / 500 uppercase</p>
      </section>

      {/* shadcn / Base UI components (step 0.3) */}
      <section className="mt-10">
        <p className="text-label text-muted-foreground">Komponente</p>
        <h2 className="text-h1 mt-1">shadcn + Base UI</h2>

        {/* Buttons */}
        <div className="mt-4 flex flex-wrap items-center gap-2">
          <Button>Default</Button>
          <Button variant="secondary">Secondary</Button>
          <Button variant="outline">Outline</Button>
          <Button variant="ghost">Ghost</Button>
          <Button variant="destructive">Destructive</Button>
        </div>

        {/* Badges */}
        <div className="mt-4 flex flex-wrap items-center gap-2">
          <Badge>Default</Badge>
          <Badge variant="secondary">Secondary</Badge>
          <Badge variant="outline">Outline</Badge>
          <Badge variant="destructive">Destructive</Badge>
        </div>

        {/* Card + Input + Switch */}
        <Card className="card-interactive mt-4 max-w-sm">
          <CardHeader>
            <CardTitle>Nova porudžbina</CardTitle>
            <CardDescription>
              Kartica sa hover-lift efektom (card-interactive).
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <Input placeholder="Pretraži porudžbine..." />
            <label className="text-body flex items-center gap-2">
              <Switch defaultChecked />
              Zvučne notifikacije
            </label>
          </CardContent>
        </Card>
      </section>
    </main>
  );
}
