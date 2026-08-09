import 'package:flutter_test/flutter_test.dart';
import 'package:travel_together_app/models/models.dart';

void main() {
  test('trip duration label', () {
    const room = TravelRoom(id: 'test', name: '여행', tripDays: 3);
    expect(room.tripDurationLabel, '2박 3일');
  });
}
