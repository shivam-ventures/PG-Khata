import Link from "next/link";
import { redirect } from "next/navigation";
import { Building2, Users, User } from "lucide-react";

import { createClient } from "@/services/supabase/server";
import { ROLE_HOME } from "@/lib/constants";
import { isDevBypassEnabled } from "@/lib/dev-bypass";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";

const PREVIEW_ROLES = [
  { role: "owner" as const, label: "Owner", description: "Cross-property dashboard", icon: Building2 },
  { role: "manager" as const, label: "Manager", description: "Today's action items", icon: Users },
  { role: "tenant" as const, label: "Tenant", description: "Rent & complaints", icon: User },
];

/** Root route: bounce to /login, or straight to the right role home if already signed in. */
export default async function RootPage() {
  if (isDevBypassEnabled()) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-6 bg-background px-4">
        <div className="flex flex-col items-center gap-2 text-center">
          <span className="rounded-full bg-warning/10 px-3 py-1 text-xs font-medium text-warning">
            Dev preview mode — no Supabase connected
          </span>
          <h1 className="text-xl font-semibold">Pick a role to preview</h1>
          <p className="max-w-sm text-sm text-muted-foreground">
            Real phone-OTP login is fully wired up — this picker only exists because
            NEXT_PUBLIC_DEV_BYPASS_AUTH=true is set in .env.local. Remove it once Supabase is connected.
          </p>
        </div>
        <div className="grid w-full max-w-2xl grid-cols-1 gap-4 sm:grid-cols-3">
          {PREVIEW_ROLES.map(({ role, label, description, icon: Icon }) => (
            <Link key={role} href={ROLE_HOME[role]}>
              <Card className="cursor-pointer transition-shadow hover:shadow-md">
                <CardHeader className="items-center text-center">
                  <div className="mb-1 flex h-10 w-10 items-center justify-center rounded-full bg-primary-50">
                    <Icon className="h-5 w-5 text-primary" />
                  </div>
                  <CardTitle className="text-base">{label}</CardTitle>
                  <CardDescription>{description}</CardDescription>
                </CardHeader>
                <CardContent />
              </Card>
            </Link>
          ))}
        </div>
      </div>
    );
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const { data: profile } = await supabase.from("profiles").select("role").eq("id", user.id).single();
  redirect(profile ? ROLE_HOME[profile.role] : "/login");
}
