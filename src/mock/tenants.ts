import type { Tenant } from "@/types/domain";

/** roomBed is the display label — kept in sync with mock/rooms.ts bed assignments by seed data, not computed, since both are static fixtures for this phase. */
export const TENANTS: Tenant[] = [
  { id: "t-ravi", name: "Ravi Kumar", phone: "+91 98765 43210", propertyId: "hsr", roomBed: "101 - A", rent: 6500, joinedAt: "2025-06-01", status: "Active", pending: false },
  { id: "t-amit", name: "Amit Shah", phone: "+91 98765 11122", propertyId: "hsr", roomBed: "101 - B", rent: 6500, joinedAt: "2025-07-15", status: "Active", pending: false },
  { id: "t-suresh", name: "Suresh Naik", phone: "+91 90000 22233", propertyId: "hsr", roomBed: "102 - A", rent: 7500, joinedAt: "2024-11-10", status: "Notice period", pending: false },
  { id: "t-deepak", name: "Deepak Rao", phone: "+91 90000 33344", propertyId: "hsr", roomBed: "102 - B", rent: 7500, joinedAt: "2025-01-20", status: "Active", pending: false },
  { id: "t-manoj", name: "Manoj Patil", phone: "+91 90000 44455", propertyId: "hsr", roomBed: "201 - A", rent: 6500, joinedAt: "2025-03-05", status: "Active", pending: false },
  { id: "t-ayesha", name: "Ayesha Khan", phone: "+91 98123 22334", propertyId: "hsr", roomBed: "A-108 - A", rent: 9000, joinedAt: "2025-04-12", status: "Active", pending: false },
  { id: "t-rahul-s", name: "Rahul Sharma", phone: "+91 98111 22337", propertyId: "hsr", roomBed: "B-204 - A", rent: 8500, joinedAt: "2025-05-18", status: "Active", pending: false },
  { id: "t-vikram", name: "Vikram Rao", phone: "+91 98111 44556", propertyId: "hsr", roomBed: "C-301 - A", rent: 7500, joinedAt: "2024-08-01", status: "Notice period", pending: false },
  { id: "t-vikas", name: "Vikas Gowda", phone: "+91 99887 77661", propertyId: "kor", roomBed: "G1 - A", rent: 8000, joinedAt: "2025-02-20", status: "Active", pending: false },
  { id: "t-rahul-j", name: "Rahul Jain", phone: "+91 99887 88772", propertyId: "kor", roomBed: "G1 - B", rent: 8000, joinedAt: "2025-09-01", status: "Active", pending: false },
  { id: "t-priya", name: "Priya Menon", phone: "+91 98123 45566", propertyId: "ind", roomBed: "G1 - A", rent: 12000, joinedAt: "2025-01-05", status: "Active", pending: false },
  { id: "t-karthik", name: "Karthik Iyer", phone: "+91 90112 33445", propertyId: "hsr", roomBed: "", rent: 0, joinedAt: null, status: "Active", pending: true },
];
