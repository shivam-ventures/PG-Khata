import type { LucideIcon } from "lucide-react";
import { LayoutDashboard, Building2, Users, Wallet, MessageSquareWarning, Settings } from "lucide-react";

/** The four roles from the product plan. Super Admin has no end-user UI in Phase 0 — internal/support only. */
export const ROLES = ["owner", "manager", "tenant", "super_admin"] as const;
export type Role = (typeof ROLES)[number];

export type NavItem = {
  label: string;
  href: string;
  icon: LucideIcon;
};

/** Bottom tab bar (mobile) / sidebar (desktop) items, per role. Keep to 4 max for the bottom tab bar. */
export const NAV_ITEMS: Record<Extract<Role, "owner" | "manager" | "tenant">, NavItem[]> = {
  owner: [
    { label: "Dashboard", href: "/owner/dashboard", icon: LayoutDashboard },
    { label: "Properties", href: "/owner/properties", icon: Building2 },
    { label: "Tenants", href: "/owner/tenants", icon: Users },
    { label: "Collections", href: "/owner/collections", icon: Wallet },
  ],
  manager: [
    { label: "Today", href: "/manager/dashboard", icon: LayoutDashboard },
    { label: "Tenants", href: "/manager/tenants", icon: Users },
    { label: "Payments", href: "/manager/payments", icon: Wallet },
    { label: "Complaints", href: "/manager/complaints", icon: MessageSquareWarning },
  ],
  tenant: [
    { label: "Home", href: "/tenant/dashboard", icon: LayoutDashboard },
    { label: "Payments", href: "/tenant/payments", icon: Wallet },
    { label: "Complaints", href: "/tenant/complaints", icon: MessageSquareWarning },
    { label: "Settings", href: "/tenant/settings", icon: Settings },
  ],
};

export const ROLE_HOME: Record<Role, string> = {
  owner: "/owner/dashboard",
  manager: "/manager/dashboard",
  tenant: "/tenant/dashboard",
  super_admin: "/owner/dashboard", // Super Admin support tooling is a later phase; not a default landing surface.
};
