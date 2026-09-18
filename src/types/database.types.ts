/**
 * Hand-written placeholder types matching supabase/schema.sql.
 *
 * Once the schema is applied to a real Supabase project, regenerate this
 * file properly with:
 *   npx supabase gen types typescript --project-id <your-project-ref> > src/types/database.types.ts
 * That command needs the Supabase CLI and project access, which is a
 * later setup step — this file keeps the app type-safe until then.
 */

export type Role = "owner" | "manager" | "tenant" | "super_admin";
export type BedStatus = "vacant" | "occupied" | "hold";
export type PaymentMode = "cash" | "upi" | "card";
export type PaymentStatus = "paid" | "due" | "overdue" | "partial";
export type ComplaintStatus = "open" | "in_progress" | "resolved";
export type IdDocumentType = "id_front" | "id_back" | "photo" | "other";
export type TenancyStatus =
  | "pending_approval"
  | "pending_profile"
  | "active"
  | "notice_period"
  | "moved_out"
  | "declined";
export type TenancySource = "staff_created" | "tenant_requested";
export type WhatsappFlow = "tenant_onboarding" | "raise_complaint" | "confirm_payment";
export type WhatsappConversationStatus = "active" | "completed" | "expired" | "abandoned";

export interface Database {
  public: {
    Tables: {
      organizations: {
        Row: {
          id: string;
          name: string;
          owner_user_id: string;
          created_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["organizations"]["Row"]> & {
          name: string;
          owner_user_id: string;
        };
        Update: Partial<Database["public"]["Tables"]["organizations"]["Row"]>;
      };
      profiles: {
        Row: {
          id: string; // matches auth.users.id
          org_id: string | null; // fixed home org for Owner/Manager/Super Admin; not meaningful for Tenant
          role: Role;
          full_name: string;
          phone: string;
          property_scope: string[]; // property ids this user (manager) can access; empty = all (owner/admin)
          created_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["profiles"]["Row"]> & { id: string; role: Role };
        Update: Partial<Database["public"]["Tables"]["profiles"]["Row"]>;
      };
      tenant_profiles: {
        // Identity fields that persist across every tenancy this person
        // has, on any owner's property — see docs/DECISIONS.md.
        Row: {
          id: string; // matches profiles.id
          emergency_contact_name: string | null;
          emergency_contact_phone: string | null;
          created_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["tenant_profiles"]["Row"]> & { id: string };
        Update: Partial<Database["public"]["Tables"]["tenant_profiles"]["Row"]>;
      };
      properties: {
        Row: {
          id: string;
          org_id: string;
          name: string;
          address: string | null;
          slug: string | null; // shareable "join this PG directly" link
          amenities: string[];
          cover_photo_url: string | null;
          created_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["properties"]["Row"]> & { org_id: string; name: string };
        Update: Partial<Database["public"]["Tables"]["properties"]["Row"]>;
      };
      rooms: {
        Row: {
          id: string;
          property_id: string;
          room_no: string;
          created_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["rooms"]["Row"]> & { property_id: string; room_no: string };
        Update: Partial<Database["public"]["Tables"]["rooms"]["Row"]>;
      };
      beds: {
        Row: {
          id: string;
          room_id: string;
          bed_no: string;
          status: BedStatus;
          listed_rent: number | null; // advertised rent shown in the public listing
          listed_deposit: number | null;
          created_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["beds"]["Row"]> & { room_id: string; bed_no: string };
        Update: Partial<Database["public"]["Tables"]["beds"]["Row"]>;
      };
      tenancies: {
        // One row per stay — a specific person at a specific bed, for a
        // specific owner. Identity lives on profiles/tenant_profiles
        // instead, so it survives a transfer or a move to a different
        // owner. See docs/DECISIONS.md.
        Row: {
          id: string;
          profile_id: string;
          bed_id: string;
          status: TenancyStatus;
          source: TenancySource;
          move_in_date: string | null;
          expected_move_in_date: string | null;
          move_out_date: string | null;
          rent_amount: number; // the actually-agreed rent for this tenancy
          rent_due_day: number; // day of month, e.g. 5
          security_deposit_amount: number;
          security_deposit_collected_at: string | null;
          agreement_accepted_at: string | null; // this property's house rules
          created_by: string | null; // Manager/Owner who added this record; null if tenant self-requested
          created_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["tenancies"]["Row"]> & {
          profile_id: string;
          bed_id: string;
        };
        Update: Partial<Database["public"]["Tables"]["tenancies"]["Row"]>;
      };
      tenant_invite_links: {
        // Magic-link tokens for tenant self-serve profile completion
        // (staff-initiated path only). Resolved server-side with the
        // service-role key, not via RLS — see the comment on this table
        // in supabase/schema.sql.
        Row: {
          id: string;
          tenancy_id: string;
          token: string;
          expires_at: string;
          used_at: string | null;
          created_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["tenant_invite_links"]["Row"]> & {
          tenancy_id: string;
          token: string;
          expires_at: string;
        };
        Update: Partial<Database["public"]["Tables"]["tenant_invite_links"]["Row"]>;
      };
      whatsapp_conversations: {
        // State machine for inbound WhatsApp reply-driven flows. V2, not
        // MVP — see docs/DECISIONS.md. Written only by the webhook
        // handler via the service-role key.
        Row: {
          id: string;
          phone: string;
          tenancy_id: string | null; // resolved once the flow can identify which stay this is about
          flow: WhatsappFlow;
          current_step: string;
          context: Record<string, unknown>; // answers collected so far
          status: WhatsappConversationStatus;
          last_message_at: string;
          expires_at: string; // WhatsApp's 24h session window, not a data expiry
          created_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["whatsapp_conversations"]["Row"]> & {
          phone: string;
          flow: WhatsappFlow;
          expires_at: string;
        };
        Update: Partial<Database["public"]["Tables"]["whatsapp_conversations"]["Row"]>;
      };
      id_documents: {
        // Deliberately NOT Aadhaar e-KYC — just a stored photo/file with a
        // manual "checked by staff" flag. Scoped per tenancy, not shared
        // across owners. See docs/DECISIONS.md.
        Row: {
          id: string;
          tenancy_id: string;
          document_type: IdDocumentType;
          file_url: string;
          uploaded_by: string;
          checked_by_staff: boolean;
          created_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["id_documents"]["Row"]> & {
          tenancy_id: string;
          document_type: IdDocumentType;
          file_url: string;
          uploaded_by: string;
        };
        Update: Partial<Database["public"]["Tables"]["id_documents"]["Row"]>;
      };
      payments: {
        Row: {
          id: string;
          tenancy_id: string;
          amount: number;
          mode: PaymentMode;
          status: PaymentStatus;
          recorded_by: string;
          gateway_ref: string | null;
          period_month: string; // e.g. '2026-09-01', the rent month this payment covers
          paid_at: string | null;
          created_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["payments"]["Row"]> & {
          tenancy_id: string;
          amount: number;
          mode: PaymentMode;
          recorded_by: string;
          period_month: string;
        };
        Update: Partial<Database["public"]["Tables"]["payments"]["Row"]>;
      };
      complaints: {
        Row: {
          id: string;
          tenancy_id: string;
          property_id: string;
          category: string;
          description: string;
          status: ComplaintStatus;
          assigned_to: string | null;
          created_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["complaints"]["Row"]> & {
          tenancy_id: string;
          property_id: string;
          category: string;
          description: string;
        };
        Update: Partial<Database["public"]["Tables"]["complaints"]["Row"]>;
      };
      reminder_log: {
        // Backs both tenant rent reminders and the Manager daily WhatsApp
        // digest (Phase 4) — one row per message actually sent, so a
        // digest/reminder is never sent twice for the same event.
        Row: {
          id: string;
          recipient_user_id: string;
          channel: "whatsapp" | "sms";
          kind: "tenant_rent_reminder" | "manager_daily_digest";
          payload: Record<string, unknown>;
          sent_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["reminder_log"]["Row"]> & {
          recipient_user_id: string;
          channel: "whatsapp" | "sms";
          kind: "tenant_rent_reminder" | "manager_daily_digest";
        };
        Update: Partial<Database["public"]["Tables"]["reminder_log"]["Row"]>;
      };
    };
    Views: {
      // Tenant-facing discovery — public, no RLS, listing-safe columns
      // only. See the comments on these views in supabase/schema.sql.
      public_property_listings: {
        Row: {
          id: string;
          name: string;
          address: string | null;
          slug: string | null;
          amenities: string[];
          cover_photo_url: string | null;
          vacant_beds: number;
          rent_from: number | null;
        };
      };
      public_bed_listings: {
        Row: {
          bed_id: string;
          property_id: string;
          room_no: string;
          bed_no: string;
          listed_rent: number | null;
          listed_deposit: number | null;
        };
      };
    };
  };
}
