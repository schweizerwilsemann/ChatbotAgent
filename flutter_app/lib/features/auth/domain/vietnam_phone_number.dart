enum VietnamMobileCarrier {
  viettel('Viettel'),
  vinaphone('VinaPhone'),
  mobifone('MobiFone');

  const VietnamMobileCarrier(this.label);

  final String label;
}

class VietnamPhoneNumber {
  VietnamPhoneNumber._();

  static const Map<VietnamMobileCarrier, Set<String>> _carrierPrefixes = {
    VietnamMobileCarrier.viettel: {
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
    },
    VietnamMobileCarrier.vinaphone: {
      '081',
      '082',
      '083',
      '084',
      '085',
      '088',
      '091',
      '094',
    },
    VietnamMobileCarrier.mobifone: {
      '070',
      '076',
      '077',
      '078',
      '079',
      '089',
      '090',
      '093',
    },
  };

  static String normalize(String phone) {
    final compact = phone.trim().replaceAll(RegExp(r'[\s().-]'), '');
    if (compact.startsWith('+84')) {
      return '0${compact.substring(3)}';
    }
    if (compact.startsWith('84') && compact.length == 11) {
      return '0${compact.substring(2)}';
    }
    return compact;
  }

  static bool hasValidFormat(String phone) {
    return RegExp(r'^0\d{9}$').hasMatch(normalize(phone));
  }

  static VietnamMobileCarrier? identifyCarrier(String phone) {
    final normalized = normalize(phone);
    if (!RegExp(r'^0\d{9}$').hasMatch(normalized)) return null;

    final prefix = normalized.substring(0, 3);
    for (final entry in _carrierPrefixes.entries) {
      if (entry.value.contains(prefix)) return entry.key;
    }
    return null;
  }

  static String? validateForRegistration(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }
    if (!hasValidFormat(phone)) {
      return 'Số điện thoại phải có 10 chữ số';
    }
    if (identifyCarrier(phone) == null) {
      return 'Chỉ hỗ trợ đầu số Viettel, VinaPhone hoặc MobiFone';
    }
    return null;
  }
}
