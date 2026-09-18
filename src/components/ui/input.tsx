import * as React from "react";
import { cn } from "@/lib/utils";

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  /** Inline error message — also sets aria-invalid and a danger border. */
  error?: string;
  leadingIcon?: React.ReactNode;
}

const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, error, leadingIcon, ...props }, ref) => {
    return (
      <div className="w-full">
        <div className="relative flex items-center">
          {leadingIcon && (
            <span className="pointer-events-none absolute left-3 flex items-center text-muted-foreground">
              {leadingIcon}
            </span>
          )}
          <input
            type={type}
            ref={ref}
            aria-invalid={!!error || undefined}
            className={cn(
              "flex h-11 w-full rounded-sm border border-input bg-background px-3 py-2 text-sm text-foreground shadow-sm transition-colors placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50",
              leadingIcon && "pl-9",
              error && "border-danger focus-visible:ring-danger",
              className
            )}
            {...props}
          />
        </div>
        {error && <p className="mt-1.5 text-xs text-danger">{error}</p>}
      </div>
    );
  }
);
Input.displayName = "Input";

export { Input };
