"use client";

import * as React from "react";
import { Phone } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export function PhoneStep({
  onSubmit,
  loading,
}: {
  onSubmit: (phone: string) => void;
  loading: boolean;
}) {
  const [phone, setPhone] = React.useState("");
  const [error, setError] = React.useState<string>();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const digits = phone.replace(/\D/g, "");
    if (digits.length !== 10) {
      setError("Enter a valid 10-digit mobile number");
      return;
    }
    setError(undefined);
    onSubmit(`+91${digits}`);
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="phone">Mobile number</Label>
        <Input
          id="phone"
          type="tel"
          inputMode="numeric"
          autoComplete="tel"
          placeholder="98765 43210"
          leadingIcon={<Phone className="h-4 w-4" />}
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          error={error}
          autoFocus
        />
      </div>
      <Button type="submit" size="lg" loading={loading} className="w-full">
        Send OTP
      </Button>
    </form>
  );
}
