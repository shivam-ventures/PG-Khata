import { Building2, Wallet, Users, MessageSquareWarning } from "lucide-react";

import { StatCard } from "@/components/stat-card";
import { EmptyState } from "@/components/empty-state";

/**
 * Phase 0: structure + empty states only, wired to real Supabase queries in
 * Phase 1 (occupancy) and Phase 3 (collections). This is the consolidated,
 * cross-property view that's the actual value proposition for a multi-PG
 * owner (Section 2.1 / Section 6 of the product plan) — so it's built first,
 * even though it starts out empty.
 */
export default function OwnerDashboardPage() {
  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Good morning</h1>
        <p className="text-sm text-muted-foreground">Here's how all your properties are doing today.</p>
      </div>

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label="Properties" value="0" icon={Building2} />
        <StatCard label="Occupancy" value="—" icon={Users} />
        <StatCard label="Collected this month" value="₹0" icon={Wallet} />
        <StatCard label="Open complaints" value="0" icon={MessageSquareWarning} />
      </div>

      <EmptyState
        icon={Building2}
        title="Add your first property"
        description="Set up rooms and beds for a PG you manage — occupancy and collections will start showing up here the moment tenants and payments are added."
        actionLabel="Add property"
      />
    </div>
  );
}
