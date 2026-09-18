import { RoleShell } from "@/components/app-shell/role-shell";
import { NAV_ITEMS } from "@/lib/constants";
import { requireRole } from "@/lib/auth";

export default async function TenantLayout({ children }: { children: React.ReactNode }) {
  const profile = await requireRole("tenant");
  const initials = profile.full_name
    ? profile.full_name.split(" ").map((n) => n[0]).slice(0, 2).join("").toUpperCase()
    : "T";

  return (
    <RoleShell items={NAV_ITEMS.tenant} roleLabel="Tenant" userInitials={initials}>
      {children}
    </RoleShell>
  );
}
