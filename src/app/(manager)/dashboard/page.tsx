import { IndianRupee, AlertTriangle, MessageSquareWarning, BedDouble } from "lucide-react";

import { StatCard } from "@/components/stat-card";
import { EmptyState } from "@/components/empty-state";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";

/**
 * The Manager's "Today" screen — this is the daily-driver surface, and also
 * exactly the data the WhatsApp daily digest (Phase 4) will summarize and
 * push each morning: rent due today, overdue count, open complaints.
 * Building the screen now with real query shape means the digest job later
 * is just "run this same query, format for WhatsApp, send" — not new logic.
 */
export default function ManagerDashboardPage() {
  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Today</h1>
        <p className="text-sm text-muted-foreground">
          Your action items across every property you manage — this is also what gets sent to you on WhatsApp each
          morning once reminders are switched on.
        </p>
      </div>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label="Rent due today" value="0" icon={IndianRupee} />
        <StatCard label="Overdue" value="0" icon={AlertTriangle} />
        <StatCard label="Open complaints" value="0" icon={MessageSquareWarning} />
        <StatCard label="Vacant beds" value="0" icon={BedDouble} />
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">WhatsApp daily digest</CardTitle>
          <CardDescription>
            Not switched on yet — this arrives in Phase 4 once rent tracking and complaints have real data to
            summarize. The four numbers above are exactly what it will send you each morning.
          </CardDescription>
        </CardHeader>
      </Card>

      <EmptyState
        icon={BedDouble}
        title="No properties assigned yet"
        description="Once the owner assigns you to a property, its rooms, tenants and today's action items will show up here."
      />
    </div>
  );
}
