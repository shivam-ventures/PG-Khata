import type { Property } from "@/types/domain";

/**
 * Seed data for the application-development phase — replaced by real
 * Supabase queries once the database phase lands, behind the same
 * feature service functions (see src/features/*/services).
 */
export const PROPERTIES: Property[] = [
  {
    id: "hsr",
    name: "HSR PG",
    address: "27th Main, HSR Layout, Bengaluru",
    managerId: "mgr-ramesh",
    managerName: "Ramesh K.",
  },
  {
    id: "kor",
    name: "Koramangala PG",
    address: "5th Block, Koramangala, Bengaluru",
    managerId: "mgr-divya",
    managerName: "Divya S.",
  },
  {
    id: "ind",
    name: "Indiranagar PG",
    address: "100ft Road, Indiranagar, Bengaluru",
    managerId: "mgr-ramesh",
    managerName: "Ramesh K.",
  },
];
