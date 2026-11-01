// PG Khata — seed script for the real backend.
//
// Auth users can't be created by plain SQL (supabase/seed.sql, which
// `supabase db reset` runs, has no access to the Admin API) — so this
// script creates the demo accounts + realistic org/property/room/tenant/
// payment/complaint data via the Admin API + service-role table access,
// ported 1:1 from the current Flutter mocks (MockPropertiesRepository,
// MockRoomsRepository, MockTenantsRepository, MockPaymentsRepository,
// MockComplaintsRepository) so every existing screen has real data to
// render against once the Supabase repositories are wired in.
//
// Run with: node supabase/seed-users.mjs
// Reads SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY from .env.local.
// Safe to re-run: every step checks for an existing row first.

import { createClient } from "@supabase/supabase-js";
import { readFileSync } from "node:fs";

function loadEnvLocal() {
  const text = readFileSync(new URL("../.env.local", import.meta.url), "utf8");
  const env = {};
  for (const line of text.split("\n")) {
    const match = line.match(/^([A-Z_]+)=(.*)$/);
    if (match) env[match[1]] = match[2];
  }
  return env;
}

const env = loadEnvLocal();
const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);

async function findOrCreateAuthUser(phoneDigitsWithCountryCode, fullName) {
  const { data: existingProfile } = await supabase
    .from("profiles")
    .select("id")
    .eq("phone", phoneDigitsWithCountryCode.slice(2)) // stored without country code, see below
    .maybeSingle();
  if (existingProfile) return existingProfile.id;

  const { data: created, error } = await supabase.auth.admin.createUser({
    phone: phoneDigitsWithCountryCode,
    phone_confirm: true,
    user_metadata: { full_name: fullName },
  });
  if (error) {
    if (error.message?.includes("already been registered")) {
      // Created in a previous run but the profiles insert failed/was skipped.
      const { data: list } = await supabase.auth.admin.listUsers({ perPage: 200 });
      const found = list.users.find((u) => u.phone === phoneDigitsWithCountryCode);
      if (found) return found.id;
    }
    throw error;
  }
  return created.user.id;
}

async function upsertProfile(id, role, fullName, phoneDigitsWithCountryCode) {
  const { error } = await supabase.from("profiles").upsert({
    id,
    role,
    full_name: fullName,
    phone: phoneDigitsWithCountryCode.slice(2), // strip "91" country code, matches AppUser.phone's current shape
  });
  if (error) throw error;
}

async function main() {
  console.log("Creating demo accounts...");

  const ownerId = await findOrCreateAuthUser("919876543210", "Anita Sharma");
  await upsertProfile(ownerId, "owner", "Anita Sharma", "919876543210");

  const rameshId = await findOrCreateAuthUser("919876500000", "Ramesh Kumar");
  await upsertProfile(rameshId, "manager", "Ramesh Kumar", "919876500000");

  const divyaId = await findOrCreateAuthUser("919900011122", "Divya S.");
  await upsertProfile(divyaId, "manager", "Divya S.", "919900011122");

  const tenantSeed = [
    { key: "t1", name: "Ravi Kumar", phone: "919876543211", propertyKey: "hsr", roomNumber: "101", bedLabel: "A", rent: 6500, joined: "2025-06-01" },
    { key: "t2", name: "Amit Shah", phone: "919876511122", propertyKey: "hsr", roomNumber: "101", bedLabel: "B", rent: 6500, joined: "2025-07-15" },
    { key: "t3", name: "Suresh Naik", phone: "919000022233", propertyKey: "hsr", roomNumber: "102", bedLabel: "A", rent: 7500, joined: "2024-11-10", status: "notice_period" },
    { key: "t4", name: "Deepak Rao", phone: "919000033344", propertyKey: "hsr", roomNumber: "102", bedLabel: "B", rent: 7500, joined: "2025-03-01" },
    { key: "t5", name: "Manoj Patil", phone: "919000044455", propertyKey: "hsr", roomNumber: "201", bedLabel: "A", rent: 6500, joined: "2025-05-20" },
    { key: "t6", name: "Ayesha Khan", phone: "919811122334", propertyKey: "hsr", roomNumber: "A-108", bedLabel: "A", rent: 9000, joined: "2025-08-01" },
    { key: "t7", name: "Rahul Sharma", phone: "919822233445", propertyKey: "hsr", roomNumber: "B-204", bedLabel: "A", rent: 8500, joined: "2025-04-12", deposit: 17000 },
    { key: "t8", name: "Vikram Rao", phone: "919833344556", propertyKey: "hsr", roomNumber: "C-301", bedLabel: "A", rent: 7500, joined: "2025-02-01", status: "notice_period" },
    { key: "t9", name: "Vikas Gowda", phone: "919988777661", propertyKey: "kor", roomNumber: "G1", bedLabel: "A", rent: 8000, joined: "2025-02-20" },
    { key: "t10", name: "Rahul Jain", phone: "919988788772", propertyKey: "kor", roomNumber: "G1", bedLabel: "B", rent: 8000, joined: "2025-03-10" },
    { key: "t11", name: "Priya Menon", phone: "919812345566", propertyKey: "ind", roomNumber: "G1", bedLabel: "A", rent: 12000, joined: "2025-01-05" },
  ];

  const tenantProfileIds = {};
  for (const t of tenantSeed) {
    const id = await findOrCreateAuthUser(t.phone, t.name);
    await upsertProfile(id, "tenant", t.name, t.phone);
    tenantProfileIds[t.key] = id;
  }

  console.log("Creating organization...");
  let { data: org } = await supabase.from("organizations").select("id").eq("owner_user_id", ownerId).maybeSingle();
  if (!org) {
    const { data, error } = await supabase
      .from("organizations")
      .insert({ name: "Anita Sharma's PGs", owner_user_id: ownerId })
      .select("id")
      .single();
    if (error) throw error;
    org = data;
  }

  console.log("Creating properties...");
  const propertySeed = [
    { key: "hsr", name: "HSR PG", address: "27th Main, HSR Layout, Bengaluru", totalBeds: 20, managers: [rameshId] },
    { key: "kor", name: "Koramangala PG", address: "5th Block, Koramangala, Bengaluru", totalBeds: 18, managers: [divyaId] },
    { key: "ind", name: "Indiranagar PG", address: "100ft Road, Indiranagar, Bengaluru", totalBeds: 11, managers: [rameshId] },
  ];

  const propertyIds = {};
  for (const p of propertySeed) {
    let { data: existing } = await supabase
      .from("properties")
      .select("id")
      .eq("org_id", org.id)
      .eq("name", p.name)
      .maybeSingle();
    if (!existing) {
      const { data, error } = await supabase
        .from("properties")
        .insert({ org_id: org.id, name: p.name, address: p.address, total_beds: p.totalBeds })
        .select("id")
        .single();
      if (error) throw error;
      existing = data;
    }
    propertyIds[p.key] = existing.id;

    for (const managerId of p.managers) {
      const { data: existingAssignment } = await supabase
        .from("property_managers")
        .select("id")
        .eq("property_id", existing.id)
        .eq("manager_user_id", managerId)
        .is("unassigned_at", null)
        .maybeSingle();
      if (!existingAssignment) {
        const { error } = await supabase
          .from("property_managers")
          .insert({ property_id: existing.id, manager_user_id: managerId, assigned_by: ownerId });
        if (error) throw error;
      }
    }
  }

  console.log("Creating rooms and beds...");
  const roomSeed = [
    { propertyKey: "hsr", floor: "Ground Floor", number: "101", sharing: "triple", rent: 6500, beds: ["A", "B", "C"] },
    { propertyKey: "hsr", floor: "Ground Floor", number: "102", sharing: "double", rent: 7500, beds: ["A", "B"] },
    { propertyKey: "hsr", floor: "First Floor", number: "201", sharing: "triple", rent: 6500, beds: ["A", "B", "C"] },
    { propertyKey: "hsr", floor: "First Floor", number: "A-108", sharing: "single", rent: 9000, beds: ["A"] },
    { propertyKey: "hsr", floor: "Second Floor", number: "B-204", sharing: "single", rent: 8500, beds: ["A"] },
    { propertyKey: "hsr", floor: "Third Floor", number: "C-301", sharing: "single", rent: 7500, beds: ["A"] },
    { propertyKey: "kor", floor: "Ground Floor", number: "G1", sharing: "double", rent: 8000, beds: ["A", "B"] },
    { propertyKey: "ind", floor: "Ground Floor", number: "G1", sharing: "single", rent: 12000, beds: ["A"] },
  ];

  const bedIds = {}; // key: "propertyKey-roomNumber-bedLabel"
  for (const r of roomSeed) {
    const propertyId = propertyIds[r.propertyKey];
    let { data: existingRoom } = await supabase
      .from("rooms")
      .select("id")
      .eq("property_id", propertyId)
      .eq("room_number", r.number)
      .maybeSingle();
    if (!existingRoom) {
      const { data, error } = await supabase
        .from("rooms")
        .insert({
          property_id: propertyId,
          floor_label: r.floor,
          room_number: r.number,
          sharing_type: r.sharing,
          rent_per_bed: r.rent,
        })
        .select("id")
        .single();
      if (error) throw error;
      existingRoom = data;
    }

    for (const label of r.beds) {
      let { data: existingBed } = await supabase
        .from("beds")
        .select("id")
        .eq("room_id", existingRoom.id)
        .eq("label", label)
        .maybeSingle();
      if (!existingBed) {
        const { data, error } = await supabase
          .from("beds")
          .insert({ room_id: existingRoom.id, label })
          .select("id")
          .single();
        if (error) throw error;
        existingBed = data;
      }
      bedIds[`${r.propertyKey}-${r.number}-${label}`] = existingBed.id;
    }
  }

  console.log("Creating tenancies...");
  const tenancyIds = {};
  for (const t of tenantSeed) {
    const bedId = bedIds[`${t.propertyKey}-${t.roomNumber}-${t.bedLabel}`];
    const profileId = tenantProfileIds[t.key];

    let { data: existingTenancy } = await supabase
      .from("tenancies")
      .select("id")
      .eq("profile_id", profileId)
      .eq("bed_id", bedId)
      .maybeSingle();

    if (!existingTenancy) {
      const { data, error } = await supabase.rpc("create_tenancy_for_profile", {
        p_profile_id: profileId,
        p_bed_id: bedId,
        p_rent_amount: t.rent,
        p_rent_due_day: 5,
        p_deposit_amount: t.deposit ?? null,
        p_move_in_date: t.joined,
        p_source: "staff_created",
        p_created_by: ownerId,
      });
      if (error) throw error;
      existingTenancy = data;

      if (t.status === "notice_period") {
        await supabase.from("tenancies").update({ status: "notice_period" }).eq("id", existingTenancy.id);
      }
    }
    tenancyIds[t.key] = existingTenancy.id;
  }

  console.log("Creating rent periods and payments...");
  // September 2026 — the "current" period every screen reads via
  // rent_period_status, matching MockPaymentsRepository's own dataset.
  const septemberPayments = [
    { key: "t1", due: "2026-09-05", status: "paid", method: "upi", paidAt: "2026-09-03", amount: 6500 },
    { key: "t2", due: "2026-09-05", status: "paid", method: "upi", paidAt: "2026-09-04", amount: 6500 },
    { key: "t3", due: "2026-09-10", status: "paid", method: "cash", paidAt: "2026-09-02", amount: 7500 },
    { key: "t4", due: "2026-09-10", status: "paid", method: "bank_transfer", paidAt: "2026-09-06", amount: 7500 },
    { key: "t5", due: "2026-09-20", status: "paid", method: "upi", paidAt: "2026-09-08", amount: 6500 },
    { key: "t6", due: "2026-09-25", status: null, amount: 9000 }, // no payment yet — real due-date math decides pending/overdue
    { key: "t7", due: "2026-09-28", status: null, amount: 8500 },
    { key: "t8", due: "2026-09-28", status: null, amount: 7500 },
    { key: "t9", due: "2026-09-03", status: "paid", method: "upi", paidAt: "2026-09-02", amount: 8000 },
    { key: "t10", due: "2026-09-28", status: null, amount: 8000 },
    { key: "t11", due: "2026-09-02", status: "paid", method: "bank_transfer", paidAt: "2026-09-01", amount: 12000 },
  ];

  // Rahul Sharma's (t7) earlier history, matching Tenant Payments.dc.html.
  const rahulHistory = [
    { periodMonth: "2026-08-01", due: "2026-08-28", status: "awaiting_confirmation", method: "cash", paidAt: "2026-08-03", amount: 8500 },
    { periodMonth: "2026-07-01", due: "2026-07-28", status: "paid", method: "cash", paidAt: "2026-07-02", amount: 8500 },
    { periodMonth: "2026-06-01", due: "2026-06-28", status: "paid", method: "upi", paidAt: "2026-06-04", amount: 8500 },
    { periodMonth: "2026-05-01", due: "2026-05-28", status: "paid", method: "upi", paidAt: "2026-05-05", amount: 8500 },
  ];

  async function createRentPeriodAndPayment(tenancyId, periodMonth, dueDate, amountDue, payment) {
    let { data: existingPeriod } = await supabase
      .from("rent_periods")
      .select("id")
      .eq("tenancy_id", tenancyId)
      .eq("period_month", periodMonth)
      .maybeSingle();
    if (!existingPeriod) {
      const { data, error } = await supabase
        .from("rent_periods")
        .insert({ tenancy_id: tenancyId, period_month: periodMonth, due_date: dueDate, amount_due: amountDue })
        .select("id")
        .single();
      if (error) throw error;
      existingPeriod = data;
    }

    if (payment) {
      const { data: existingPayment } = await supabase
        .from("payments")
        .select("id")
        .eq("rent_period_id", existingPeriod.id)
        .maybeSingle();
      if (!existingPayment) {
        const { data: newPayment, error } = await supabase
          .from("payments")
          .insert({
            rent_period_id: existingPeriod.id,
            amount: payment.amount,
            method: payment.method,
            recorded_by: ownerId, // seed data — attributed to the Owner for simplicity
            is_self_recorded: false,
            status: payment.status,
            paid_at: payment.paidAt,
          })
          .select("id")
          .single();
        if (error) throw error;
        await supabase
          .from("payment_allocations")
          .insert({ payment_id: newPayment.id, rent_period_id: existingPeriod.id, amount_allocated: payment.amount });
      }
    }
    return existingPeriod.id;
  }

  for (const p of septemberPayments) {
    await createRentPeriodAndPayment(
      tenancyIds[p.key],
      "2026-09-01",
      p.due,
      p.amount,
      p.status ? { status: p.status, method: p.method, paidAt: p.paidAt, amount: p.amount } : null,
    );
  }
  for (const h of rahulHistory) {
    await createRentPeriodAndPayment(tenancyIds["t7"], h.periodMonth, h.due, h.amount, h);
  }

  console.log("Creating complaints...");
  async function createComplaint(c) {
    let { data: existing } = await supabase
      .from("complaints")
      .select("id")
      .eq("property_id", propertyIds[c.propertyKey])
      .eq("title", c.title)
      .maybeSingle();
    if (existing) return existing.id;

    const { data: complaint, error } = await supabase
      .from("complaints")
      .insert({
        property_id: propertyIds[c.propertyKey],
        tenancy_id: c.tenancyKey ? tenancyIds[c.tenancyKey] : null,
        category: c.category,
        severity: c.severity,
        title: c.title,
        room_label: c.room,
        time_preference: c.timePreference,
        reported_by: c.reportedBy,
        reported_at: c.reportedAt,
      })
      .select("id")
      .single();
    if (error) throw error;

    await supabase
      .from("complaint_events")
      .insert({ complaint_id: complaint.id, event_type: "reported", actor_user_id: c.reportedBy, created_at: c.reportedAt });

    for (const event of c.events ?? []) {
      await supabase.from("complaint_events").insert({
        complaint_id: complaint.id,
        event_type: event.type,
        actor_user_id: event.actor,
        assignee: event.assignee ?? null,
        note: event.note ?? null,
        created_at: event.at,
      });
    }
    return complaint.id;
  }

  await createComplaint({
    title: "Geyser not working",
    category: "plumbing",
    severity: "high",
    propertyKey: "hsr",
    room: "B-204",
    tenancyKey: "t7",
    timePreference: "evening",
    reportedBy: tenantProfileIds.t7,
    reportedAt: "2026-09-20T10:00:00Z",
    events: [{ type: "delegated", actor: rameshId, assignee: "Electrician", at: "2026-09-20T10:30:00Z" }],
  });

  await createComplaint({
    title: "Wifi down on 2nd floor",
    category: "wifi",
    severity: "medium",
    propertyKey: "hsr",
    room: "Floor 2",
    tenancyKey: null,
    timePreference: "anytime",
    reportedBy: rameshId,
    reportedAt: "2026-09-22T05:00:00Z",
  });

  await createComplaint({
    title: "Wifi slow in room",
    category: "wifi",
    severity: "low",
    propertyKey: "hsr",
    room: "B-204",
    tenancyKey: "t7",
    timePreference: "anytime",
    reportedBy: tenantProfileIds.t7,
    reportedAt: "2026-09-20T09:00:00Z",
    events: [{ type: "resolved", actor: rameshId, at: "2026-09-21T09:00:00Z" }],
  });

  console.log("\nSeed complete.");
  console.log("Demo logins (OTP 123456 for all three):");
  console.log("  Owner:   9876543210 (Anita Sharma)");
  console.log("  Manager: 9876500000 (Ramesh Kumar)");
  console.log("  Tenant:  9822233445 (Rahul Sharma)");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
