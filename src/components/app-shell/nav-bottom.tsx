"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { NavItem } from "@/lib/constants";
import { cn } from "@/lib/utils";

/** Mobile bottom tab bar — 4 items max, role-specific, from NAV_ITEMS. */
export function NavBottom({ items }: { items: NavItem[] }) {
  const pathname = usePathname();

  return (
    <nav
      className="fixed inset-x-0 bottom-0 z-40 flex h-16 items-stretch border-t border-border bg-card lg:hidden"
      aria-label="Primary"
    >
      {items.map((item) => {
        const active = pathname?.startsWith(item.href);
        const Icon = item.icon;
        return (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              "flex flex-1 flex-col items-center justify-center gap-1 text-xs font-medium transition-colors",
              active ? "text-primary" : "text-muted-foreground"
            )}
            aria-current={active ? "page" : undefined}
          >
            <Icon className="h-5 w-5" aria-hidden />
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}
