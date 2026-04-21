import 'package:flutter_test/flutter_test.dart';
import 'package:part_approval_desktop/main.dart';

void main() {
  group('ApprovalStatus', () {
    test('uses the requested seven-step status mapping', () {
      expect(
        ApprovalStatus.values.map((status) => status.apiValue),
        orderedEquals([1, 2, 3, 4, 5, 6, 7]),
      );
      expect(
        ApprovalStatus.values.map((status) => status.label),
        orderedEquals([
          'Requested',
          'Approved',
          'Pending',
          'Collected',
          'Returned',
          'Used',
          'Disposed',
        ]),
      );
    });

    test('parses new labels and keeps legacy new label compatible', () {
      expect(ApprovalStatus.fromApiValue(1), ApprovalStatus.requested);
      expect(ApprovalStatus.fromApiValue('Approved'), ApprovalStatus.approved);
      expect(
        ApprovalStatus.fromApiValue({'id': 4, 'name': 'Collected'}),
        ApprovalStatus.collected,
      );
      expect(ApprovalStatus.fromApiValue('New'), ApprovalStatus.requested);
    });

    test('treats only disposed as closed', () {
      expect(ApprovalStatus.requested.isClosed, isFalse);
      expect(ApprovalStatus.used.isClosed, isFalse);
      expect(ApprovalStatus.disposed.isClosed, isTrue);
    });
  });

  test('builds update payloads with the new status ids', () {
    final request = PartRequest(
      id: 5001,
      partName: 'Cyan Drum Kit',
      brandId: 1,
      brand: 'Canon',
      modelId: 11,
      model: 'iR ADV DX C3926',
      machineId: 101,
      machine: 'HQ Printer A',
      categoryId: 201,
      category: 'Drum Unit',
      requestedBy: 'Aisyah',
      cost: 780,
      createdAt: '2026-04-02',
      description: 'Drum count is high and print quality shows repeated marks.',
      remark: 'Need urgent approval before next PM cycle.',
      status: ApprovalStatus.requested,
    );

    expect(
      request.toUpdatePayload(ApprovalStatus.disposed),
      containsPair('status', 7),
    );
    expect(
      request.toUpdatePayload(ApprovalStatus.disposed),
      containsPair('status_id', 7),
    );
  });
}
