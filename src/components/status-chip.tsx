import { Badge } from "@/components/ui/badge";

/**
 * Every status pill in the product goes through this component so a
 * "Paid" chip is always green and an "Overdue" chip is always red,
 * everywhere — no screen hand-picks its own status color.
 */
export type PaymentStatus = "paid" | "due" | "overdue" | "partial";
export type VerificationStatus = "verified" | "pending" | "not_submitted";
export type ComplaintStatus = "open" | "in_progress" | "resolved";

const PAYMENT_LABELS: Record<PaymentStatus, { label: string; variant: "success" | "warning" | "danger" }> = {
  paid: { label: "Paid", variant: "success" },
  due: { label: "Due", variant: "warning" },
  overdue: { label: "Overdue", variant: "danger" },
  partial: { label: "Partial", variant: "warning" },
};

const VERIFICATION_LABELS: Record<VerificationStatus, { label: string; variant: "success" | "warning" | "neutral" }> = {
  verified: { label: "Verified", variant: "success" },
  pending: { label: "Pending", variant: "warning" },
  not_submitted: { label: "Not submitted", variant: "neutral" },
};

const COMPLAINT_LABELS: Record<ComplaintStatus, { label: string; variant: "danger" | "warning" | "success" }> = {
  open: { label: "Open", variant: "danger" },
  in_progress: { label: "In progress", variant: "warning" },
  resolved: { label: "Resolved", variant: "success" },
};

export function PaymentStatusChip({ status }: { status: PaymentStatus }) {
  const { label, variant } = PAYMENT_LABELS[status];
  return <Badge variant={variant}>{label}</Badge>;
}

export function VerificationStatusChip({ status }: { status: VerificationStatus }) {
  const { label, variant } = VERIFICATION_LABELS[status];
  return <Badge variant={variant}>{label}</Badge>;
}

export function ComplaintStatusChip({ status }: { status: ComplaintStatus }) {
  const { label, variant } = COMPLAINT_LABELS[status];
  return <Badge variant={variant}>{label}</Badge>;
}
