import { RoleShell } from "@/components/app-shell/role-shell";
import { NAV_ITEMS } from "@/lib/constants";
import { requireRole } from "@/lib/auth";

export default async function ManagerLayout({ children }: { children: React.ReactNode }) {
  const profile = await requireRole("manager");
  const initials = profile.full_name
    ? profile.full_name.split(" ").map((n) => n[0]).slice(0, 2).join("").toUpperCase()
    : "M";

  return (
    <RoleShell items={NAV_ITEMS.manager} roleLabel="Manager" userInitials={initials}>
      {children}
    </RoleShell>
  );
}
