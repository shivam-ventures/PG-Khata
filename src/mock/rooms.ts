import type { Room } from "@/types/domain";

export const ROOMS: Room[] = [
  {
    id: "hsr-101", propertyId: "hsr", floor: "Ground Floor", number: "101", sharing: "Triple sharing", rentPerBed: 6500,
    beds: [
      { id: "hsr-101-a", label: "A", tenantId: "t-ravi" },
      { id: "hsr-101-b", label: "B", tenantId: "t-amit" },
      { id: "hsr-101-c", label: "C", tenantId: null },
    ],
  },
  {
    id: "hsr-102", propertyId: "hsr", floor: "Ground Floor", number: "102", sharing: "Double sharing", rentPerBed: 7500,
    beds: [
      { id: "hsr-102-a", label: "A", tenantId: "t-suresh" },
      { id: "hsr-102-b", label: "B", tenantId: "t-deepak" },
    ],
  },
  {
    id: "hsr-201", propertyId: "hsr", floor: "First Floor", number: "201", sharing: "Triple sharing", rentPerBed: 6500,
    beds: [
      { id: "hsr-201-a", label: "A", tenantId: "t-manoj" },
      { id: "hsr-201-b", label: "B", tenantId: null },
      { id: "hsr-201-c", label: "C", tenantId: null },
    ],
  },
  {
    id: "hsr-a108", propertyId: "hsr", floor: "First Floor", number: "A-108", sharing: "Single", rentPerBed: 9000,
    beds: [{ id: "hsr-a108-a", label: "A", tenantId: "t-ayesha" }],
  },
  {
    id: "hsr-b204", propertyId: "hsr", floor: "Second Floor", number: "B-204", sharing: "Single", rentPerBed: 8500,
    beds: [{ id: "hsr-b204-a", label: "A", tenantId: "t-rahul-s" }],
  },
  {
    id: "hsr-c301", propertyId: "hsr", floor: "Second Floor", number: "C-301", sharing: "Single", rentPerBed: 7500,
    beds: [{ id: "hsr-c301-a", label: "A", tenantId: "t-vikram" }],
  },
  {
    id: "kor-g1", propertyId: "kor", floor: "Ground Floor", number: "G1", sharing: "Double sharing", rentPerBed: 8000,
    beds: [
      { id: "kor-g1-a", label: "A", tenantId: "t-vikas" },
      { id: "kor-g1-b", label: "B", tenantId: "t-rahul-j" },
    ],
  },
  {
    id: "ind-g1", propertyId: "ind", floor: "Ground Floor", number: "G1", sharing: "Single", rentPerBed: 12000,
    beds: [{ id: "ind-g1-a", label: "A", tenantId: "t-priya" }],
  },
];
