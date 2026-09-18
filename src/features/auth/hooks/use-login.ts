"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { createClient } from "@/services/supabase/client";
import { ROLE_HOME } from "@/lib/constants";

type Step = "phone" | "otp";

/** Drives the two-step phone-OTP login flow used by /login for every role. */
export function useLogin() {
  const [step, setStep] = React.useState<Step>("phone");
  const [phone, setPhone] = React.useState("");
  const [loading, setLoading] = React.useState(false);
  const router = useRouter();
  const supabase = createClient();

  async function sendOtp(phoneNumber: string) {
    setLoading(true);
    setPhone(phoneNumber);
    const { error } = await supabase.auth.signInWithOtp({ phone: phoneNumber });
    setLoading(false);

    if (error) {
      toast.error("Couldn't send the code", { description: error.message });
      return;
    }
    setStep("otp");
    toast.success("Code sent", { description: `We texted a 6-digit code to ${phoneNumber}` });
  }

  async function verifyOtp(token: string) {
    setLoading(true);
    const { data, error } = await supabase.auth.verifyOtp({ phone, token, type: "sms" });
    setLoading(false);

    if (error || !data.user) {
      toast.error("That code didn't work", { description: error?.message ?? "Try again" });
      return;
    }

    const { data: profile } = await supabase.from("profiles").select("role").eq("id", data.user.id).single();

    if (!profile) {
      toast.error("No account found for this number", {
        description: "Ask your PG owner or manager to add you first.",
      });
      await supabase.auth.signOut();
      return;
    }

    router.replace(ROLE_HOME[profile.role]);
  }

  return { step, phone, loading, sendOtp, verifyOtp, resend: () => phone && sendOtp(phone) };
}
