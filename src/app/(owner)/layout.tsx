import { RoleShell } from "@/components/app-shell/role-shell";
import { NAV_ITEMS } from "@/lib/constants";
import { requireRole } from "@/lib/auth";

export default async function OwnerLayout({ children }: { children: React.ReactNode }) {
  const profile = await requireRole("owner");
  const initials = profile.full_name
    ? profile.full_name.split(" ").map((n) => n[0]).slice(0, 2).join("").toUpperCase()
    : "O";

  return (
    <RoleShell items={NAV_ITEMS.owner} roleLabel="Owner" userInitials={initials}>
      {children}
    </RoleShell>
  );
}
