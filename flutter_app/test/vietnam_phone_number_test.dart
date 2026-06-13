import 'package:flutter_test/flutter_test.dart';
import 'package:sports_venue_chatbot/features/auth/domain/vietnam_phone_number.dart';

void main() {
  test('normalizes Vietnamese international phone formats', () {
    expect(VietnamPhoneNumber.normalize('+84 90 123 4567'), '0901234567');
    expect(VietnamPhoneNumber.normalize('84901234567'), '0901234567');
  });

  test('identifies prefixes from the three supported carriers', () {
    const expectedPrefixes = {
      VietnamMobileCarrier.viettel: [
        '032',
        '033',
        '034',
        '035',
        '036',
        '037',
        '038',
        '039',
        '086',
        '096',
        '097',
        '098',
      ],
      VietnamMobileCarrier.vinaphone: [
        '081',
        '082',
        '083',
        '084',
        '085',
        '088',
        '091',
        '094',
      ],
      VietnamMobileCarrier.mobifone: [
        '070',
        '076',
        '077',
        '078',
        '079',
        '089',
        '090',
        '093',
      ],
    };

    for (final entry in expectedPrefixes.entries) {
      for (final prefix in entry.value) {
        expect(
          VietnamPhoneNumber.identifyCarrier('${prefix}1234567'),
          entry.key,
        );
      }
    }
  });

  test('rejects unsupported carrier prefixes for registration', () {
    expect(
      VietnamPhoneNumber.validateForRegistration('0921234567'),
      isNotNull,
    );
    expect(
      VietnamPhoneNumber.validateForRegistration('0901234567'),
      isNull,
    );
  });
}
