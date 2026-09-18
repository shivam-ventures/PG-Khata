"use client";

import { Building2 } from "lucide-react";

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { PhoneStep } from "@/features/auth/components/phone-step";
import { OtpStep } from "@/features/auth/components/otp-step";
import { useLogin } from "@/features/auth/hooks/use-login";

export default function LoginPage() {
  const { step, phone, loading, sendOtp, verifyOtp, resend } = useLogin();

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-background px-4">
      <div className="mb-8 flex flex-col items-center gap-2">
        <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-primary text-primary-foreground shadow-sm">
          <Building2 className="h-6 w-6" />
        </div>
        <span className="text-lg font-semibold">PG Khata</span>
      </div>

      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>{step === "phone" ? "Log in" : "Verify your number"}</CardTitle>
          <CardDescription>
            {step === "phone"
              ? "No password needed — we'll text you a one-time code."
              : "One-time codes expire after a few minutes."}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {step === "phone" ? (
            <PhoneStep onSubmit={sendOtp} loading={loading} />
          ) : (
            <OtpStep phone={phone} onSubmit={verifyOtp} onResend={resend} loading={loading} />
          )}
        </CardContent>
      </Card>
    </div>
  );
}
