/**
 * Frontend domain types for the application-development phase — modeling
 * what the approved design actually needs, not a database schema. These
 * are expected to diverge from whatever `supabase/schema.sql` ends up
 * looking like once the database is deliberately designed later; see
 * docs/domain-model-notes.md for the discovery notes behind these shapes.
 */

export type Role = "owner" | "manager" | "tenant";

export interface Profile {
  id: string;
  name: string;
  phone: string;
  role: Role;
}

export interface Property {
  id: string;
  name: string;
  address: string;
  managerId: string | null;
  managerName: string | null;
}

/** Derived from Room/Bed data, never stored — see PropertiesService.getPropertyStats. */
export interface PropertyStats {
  totalBeds: number;
  occupiedBeds: number;
  rentCollected: number;
  rentExpected: number;
  openComplaints: number;
}

export type SharingType = "Single" | "Double sharing" | "Triple sharing" | "Four sharing";

export const BEDS_PER_SHARING: Record<SharingType, number> = {
  Single: 1,
  "Double sharing": 2,
  "Triple sharing": 3,
  "Four sharing": 4,
};

export interface Bed {
  id: string;
  label: string; // A, B, C...
  tenantId: string | null;
}

export interface Room {
  id: string;
  propertyId: string;
  floor: string; // free-text grouping label, not a managed entity — see domain-model-notes.md
  number: string;
  sharing: SharingType;
  rentPerBed: number;
  beds: Bed[];
}

export type TenantStatus = "Active" | "Notice period" | "Vacated";

export interface Tenant {
  id: string;
  name: string;
  phone: string;
  propertyId: string;
  roomBed: string; // display label, e.g. "101 - A"
  rent: number;
  joinedAt: string | null;
  status: TenantStatus;
  /** Self-registered via signup/invite, not yet assigned a bed by staff. */
  pending: boolean;
}

export type PaymentMethod = "Cash" | "UPI" | "Bank Transfer";

export type PaymentStatus = "Paid" | "Pending" | "Overdue" | "Awaiting confirmation" | "Disputed";

export interface Payment {
  id: string;
  tenantId: string;
  tenantName: string;
  propertyId: string;
  room: string;
  amount: number;
  method: PaymentMethod | null;
  dueDate: string;
  paidDate: string | null;
  status: PaymentStatus;
}

export type ComplaintCategory = "Plumbing" | "Electrical" | "Wifi/Internet" | "Cleaning" | "Other";
export type ComplaintSeverity = "Low" | "Medium" | "High";
export type ComplaintStatus = "Reported" | "Delegated" | "Resolved" | "Reopened";
export type ComplaintAssignee = "Self (I'll fix it)" | "Cleaner" | "Electrician" | "Plumber" | "Outside vendor";

export interface Complaint {
  id: string;
  tenantId: string;
  tenantName: string;
  propertyId: string;
  room: string;
  title: string;
  category: ComplaintCategory;
  severity: ComplaintSeverity;
  timePref: string;
  status: ComplaintStatus;
  reportedAt: string;
  delegatedTo: ComplaintAssignee | null;
  delegatedAt: string | null;
  autoResolveDays: number;
  note: string | null;
}

export interface Announcement {
  id: string;
  propertyId: string;
  text: string;
  postedAt: string;
}

export interface NotificationPreferences {
  rentReminders: true; // mandatory, always on — see Settings.dc.html
  complaintUpdates: boolean;
  pgAnnouncements: boolean;
}
