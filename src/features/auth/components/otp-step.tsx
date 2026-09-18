"use client";

import * as React from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export function OtpStep({
  phone,
  onSubmit,
  onResend,
  loading,
}: {
  phone: string;
  onSubmit: (otp: string) => void;
  onResend: () => void;
  loading: boolean;
}) {
  const [otp, setOtp] = React.useState("");
  const [error, setError] = React.useState<string>();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (otp.length !== 6) {
      setError("Enter the 6-digit code");
      return;
    }
    setError(undefined);
    onSubmit(otp);
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="otp">Enter the code sent to {phone}</Label>
        <Input
          id="otp"
          type="text"
          inputMode="numeric"
          autoComplete="one-time-code"
          placeholder="123456"
          maxLength={6}
          value={otp}
          onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))}
          error={error}
          autoFocus
        />
      </div>
      <Button type="submit" size="lg" loading={loading} className="w-full">
        Verify & continue
      </Button>
      <button
        type="button"
        onClick={onResend}
        className="text-sm text-muted-foreground underline-offset-4 hover:text-foreground hover:underline"
      >
        Resend code
      </button>
    </form>
  );
}
