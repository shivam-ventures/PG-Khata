import type { LucideIcon } from "lucide-react";
import { ArrowDownRight, ArrowUpRight } from "lucide-react";

import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

export interface StatCardProps {
  label: string;
  value: string;
  icon: LucideIcon;
  /** Positive = up (usually good, e.g. collections); pass isPositiveGood=false for metrics where "up" is bad (e.g. overdue count). */
  trend?: { value: string; direction: "up" | "down"; isPositiveGood?: boolean };
  loading?: boolean;
  onClick?: () => void;
}

/** The one shared card behind Occupancy / Collection / Revenue stat tiles on every dashboard. */
export function StatCard({ label, value, icon: Icon, trend, loading, onClick }: StatCardProps) {
  if (loading) {
    return (
      <Card>
        <CardContent className="flex flex-col gap-3 p-5">
          <Skeleton className="h-4 w-24" />
          <Skeleton className="h-8 w-16" />
        </CardContent>
      </Card>
    );
  }

  const trendGood = trend && (trend.isPositiveGood ?? true) === (trend.direction === "up");

  return (
    <Card
      className={cn(onClick && "cursor-pointer hover:shadow-md")}
      onClick={onClick}
      role={onClick ? "button" : undefined}
    >
      <CardContent className="flex flex-col gap-2 p-5">
        <div className="flex items-center justify-between">
          <span className="text-sm text-muted-foreground">{label}</span>
          <Icon className="h-4 w-4 text-muted-foreground" aria-hidden />
        </div>
        <div className="flex items-end justify-between">
          <span className="text-2xl font-semibold tracking-tight">{value}</span>
          {trend && (
            <span
              className={cn(
                "flex items-center gap-0.5 text-xs font-medium",
                trendGood ? "text-success" : "text-danger"
              )}
            >
              {trend.direction === "up" ? (
                <ArrowUpRight className="h-3.5 w-3.5" />
              ) : (
                <ArrowDownRight className="h-3.5 w-3.5" />
              )}
              {trend.value}
            </span>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
