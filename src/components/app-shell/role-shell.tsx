import type { NavItem } from "@/lib/constants";
import { NavBottom } from "@/components/app-shell/nav-bottom";
import { NavSidebar } from "@/components/app-shell/nav-sidebar";
import { ThemeToggle } from "@/components/theme-toggle";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { isDevBypassEnabled } from "@/lib/dev-bypass";

/**
 * Shared shell for all three role areas: sidebar (desktop) or bottom tabs
 * (mobile), a top bar with the theme toggle and account menu, and a content
 * slot. Each (owner)/(manager)/(tenant) layout.tsx renders this with its
 * own NAV_ITEMS — the shell itself has no role-specific logic.
 */
export function RoleShell({
  items,
  roleLabel,
  userInitials,
  children,
}: {
  items: NavItem[];
  roleLabel: string;
  userInitials: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen bg-background">
      <NavSidebar items={items} roleLabel={roleLabel} />
      <div className="flex min-h-screen flex-1 flex-col">
        <header className="flex h-16 items-center justify-between border-b border-border bg-card px-4 lg:px-8">
          <span className="text-sm font-medium text-muted-foreground lg:hidden">PG Khata</span>
          <div className="ml-auto flex items-center gap-2">
            <ThemeToggle />
            <Avatar className="h-9 w-9">
              <AvatarFallback>{userInitials}</AvatarFallback>
            </Avatar>
          </div>
        </header>
        {isDevBypassEnabled() && (
          <div className="bg-warning/10 px-4 py-1.5 text-center text-xs font-medium text-warning lg:px-8">
            Dev preview mode — no Supabase connected, nothing here is real data
          </div>
        )}
        <main className="flex-1 px-4 pb-24 pt-6 lg:px-8 lg:pb-10">{children}</main>
        <NavBottom items={items} />
      </div>
    </div>
  );
}
