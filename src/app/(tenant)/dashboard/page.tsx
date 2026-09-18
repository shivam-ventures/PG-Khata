import { IndianRupee, MessageSquareWarning } from "lucide-react";

import { StatCard } from "@/components/stat-card";
import { EmptyState } from "@/components/empty-state";

export default function TenantDashboardPage() {
  return (
    <div className="mx-auto flex max-w-md flex-col gap-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Welcome</h1>
        <p className="text-sm text-muted-foreground">Your rent and complaints, in one place.</p>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <StatCard label="Rent status" value="—" icon={IndianRupee} />
        <StatCard label="Open complaints" value="0" icon={MessageSquareWarning} />
      </div>

      <EmptyState
        icon={IndianRupee}
        title="No payment history yet"
        description="Once your first rent payment is recorded — cash or online — you'll see it here, with a receipt for every payment."
      />
    </div>
  );
}
