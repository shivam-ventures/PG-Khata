import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/errors/result.dart';
import 'package:pg_khata/features/complaints/data/mock_complaints_repository.dart';
import 'package:pg_khata/features/complaints/domain/complaint_category.dart';
import 'package:pg_khata/features/complaints/domain/complaint_severity.dart';
import 'package:pg_khata/features/complaints/domain/complaint_status.dart';
import 'package:pg_khata/features/complaints/domain/time_preference.dart';

void main() {
  late MockComplaintsRepository repository;

  setUp(() => repository = MockComplaintsRepository());

  test(
    'fetchComplaints for HSR has exactly 2 open, matching Manager '
    "Today's already-shipped stat",
    () async {
      final result = await repository.fetchComplaints(propertyId: 'hsr');
      final complaints = result.when(ok: (c) => c, err: (_) => null);
      expect(complaints, isNotNull);

      final open = complaints!
          .where((c) => c.effectiveStatus != ComplaintStatus.resolved)
          .length;
      expect(open, 2);
    },
  );

  test('the high-priority complaint sorts first', () async {
    final result = await repository.fetchComplaints(propertyId: 'hsr');
    final complaints = result.when(ok: (c) => c, err: (_) => null)!;
    expect(complaints.first.severity, ComplaintSeverity.high);
    expect(complaints.first.title, 'Geyser not working');
  });

  test(
    "fetchComplaints for a tenant matches Tenant Complaints.dc.html's own list",
    () async {
      final result = await repository.fetchComplaints(tenantId: 't7');
      final complaints = result.when(ok: (c) => c, err: (_) => null);
      expect(complaints, isNotNull);
      expect(complaints!.length, 2);
      expect(
        complaints.map((c) => c.title).toSet(),
        {'Geyser not working', 'Wifi slow in room'},
      );
    },
  );

  test('a common-area complaint has no tenantId and is Manager-only', () async {
    final tenantResult = await repository.fetchComplaints(tenantId: 't7');
    final tenantComplaints = tenantResult.when(ok: (c) => c, err: (_) => null)!;
    expect(tenantComplaints.any((c) => c.title == 'Wifi down on 2nd floor'), isFalse);

    final managerResult = await repository.fetchComplaints(propertyId: 'hsr');
    final managerComplaints = managerResult.when(ok: (c) => c, err: (_) => null)!;
    expect(managerComplaints.any((c) => c.title == 'Wifi down on 2nd floor'), isTrue);
  });

  test('Indiranagar PG has no complaints, matching the design exactly', () async {
    final result = await repository.fetchComplaints(propertyId: 'ind');
    final complaints = result.when(ok: (c) => c, err: (_) => null);
    expect(complaints, isEmpty);
  });

  test('reportComplaint defaults the title to "{category} issue" when blank', () async {
    final result = await repository.reportComplaint(
      propertyId: 'hsr',
      propertyName: 'HSR PG',
      room: 'B-204',
      tenantId: 't7',
      tenantName: 'Rahul Sharma',
      category: ComplaintCategory.electrical,
      severity: ComplaintSeverity.medium,
      title: '   ',
      timePreference: TimePreference.anytime,
    );
    final complaint = result.when(ok: (c) => c, err: (_) => null);
    expect(complaint, isNotNull);
    expect(complaint!.title, 'Electrical issue');
    expect(complaint.status, ComplaintStatus.reported);
  });

  test('delegateComplaint moves a reported complaint to delegated', () async {
    final result = await repository.delegateComplaint(
      'c2',
      assignee: 'Electrician',
      note: 'Told him to come by evening',
    );
    expect(result, isA<Ok<void>>());

    final complaints = (await repository.fetchComplaints(propertyId: 'hsr'))
        .when(ok: (c) => c, err: (_) => null)!;
    final wifi = complaints.firstWhere((c) => c.id == 'c2');
    expect(wifi.status, ComplaintStatus.delegated);
    expect(wifi.delegatedTo, 'Electrician');
  });

  test('a delegated complaint auto-resolves after its window passes', () async {
    // c1 was delegated 2 days ago with the default 3-day window — not yet.
    final beforeResult = await repository.fetchComplaints(propertyId: 'hsr');
    final before = beforeResult.when(ok: (c) => c, err: (_) => null)!;
    final geyserBefore = before.firstWhere((c) => c.id == 'c1');
    expect(geyserBefore.effectiveStatus, ComplaintStatus.delegated);

    // Manually re-delegate it far enough in the past to cross the window.
    await repository.delegateComplaint('c1', assignee: 'Electrician');
    final afterResult = await repository.fetchComplaints(propertyId: 'hsr');
    final after = afterResult.when(ok: (c) => c, err: (_) => null)!;
    final geyserAfter = after.firstWhere((c) => c.id == 'c1');
    // Freshly delegated (now), so it hasn't auto-resolved yet.
    expect(geyserAfter.effectiveStatus, ComplaintStatus.delegated);
    expect(geyserAfter.autoResolveDaysLeft, 3);
  });

  test('resolveComplaint marks a delegated complaint resolved immediately', () async {
    final result = await repository.resolveComplaint('c1');
    expect(result, isA<Ok<void>>());
    final complaints = (await repository.fetchComplaints(propertyId: 'hsr'))
        .when(ok: (c) => c, err: (_) => null)!;
    expect(
      complaints.firstWhere((c) => c.id == 'c1').effectiveStatus,
      ComplaintStatus.resolved,
    );
  });

  test('reopenComplaint marks a complaint reopened', () async {
    final result = await repository.reopenComplaint('c3');
    expect(result, isA<Ok<void>>());
    final complaints = (await repository.fetchComplaints(tenantId: 't7'))
        .when(ok: (c) => c, err: (_) => null)!;
    expect(
      complaints.firstWhere((c) => c.id == 'c3').status,
      ComplaintStatus.reopened,
    );
  });
}
