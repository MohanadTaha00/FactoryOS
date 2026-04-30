import 'package:factoryos/data/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkOrderStatus.allowedNext', () {
    test('pending can move to assigned or cancelled', () {
      expect(
        WorkOrderStatus.pending.allowedNext,
        {WorkOrderStatus.assigned, WorkOrderStatus.cancelled},
      );
    });

    test('inProgress can submit to QA', () {
      expect(
        WorkOrderStatus.inProgress.allowedNext
            .contains(WorkOrderStatus.readyForQa),
        isTrue,
      );
    });

    test('approved can only move to completed', () {
      expect(WorkOrderStatus.approved.allowedNext, {WorkOrderStatus.completed});
    });
  });
}
