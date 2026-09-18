"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Building2 } from "lucide-react";
import type { NavItem } from "@/lib/constants";
import { cn } from "@/lib/utils";

/** Desktop sidebar — same NAV_ITEMS as the mobile bottom bar, more room to breathe. */
export function NavSidebar({ items, roleLabel }: { items: NavItem[]; roleLabel: string }) {
  const pathname = usePathname();

  return (
    <aside className="hidden w-64 shrink-0 flex-col border-r border-border bg-card lg:flex">
      <div className="flex h-16 items-center gap-2 border-b border-border px-6">
        <div className="flex h-8 w-8 items-center justify-center rounded-md bg-primary text-primary-foreground">
          <Building2 className="h-4 w-4" />
        </div>
        <div className="flex flex-col leading-tight">
          <span className="text-sm font-semibold">PG Khata</span>
          <span className="text-xs text-muted-foreground">{roleLabel}</span>
        </div>
      </div>
      <nav className="flex flex-1 flex-col gap-1 p-3" aria-label="Primary">
        {items.map((item) => {
          const active = pathname?.startsWith(item.href);
          const Icon = item.icon;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
                active ? "bg-primary-50 text-primary-700" : "text-muted-foreground hover:bg-muted hover:text-foreground"
              )}
              aria-current={active ? "page" : undefined}
            >
              <Icon className="h-4 w-4" aria-hidden />
              {item.label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
