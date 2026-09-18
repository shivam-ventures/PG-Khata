import { cn } from "@/lib/utils";

/** Always mirror the real layout's shape/size — never a lone centered spinner. */
function Skeleton({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("animate-pulse rounded-md bg-muted", className)} {...props} />;
}

export { Skeleton };
