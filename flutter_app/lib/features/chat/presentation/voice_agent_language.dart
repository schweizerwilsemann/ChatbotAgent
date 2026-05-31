enum VoiceAgentLocale {
  vietnamese,
  english,
}

class VoiceAgentText {
  VoiceAgentText._();

  static const _diacriticMap = <String, String>{
    'à': 'a',
    'á': 'a',
    'ạ': 'a',
    'ả': 'a',
    'ã': 'a',
    'â': 'a',
    'ầ': 'a',
    'ấ': 'a',
    'ậ': 'a',
    'ẩ': 'a',
    'ẫ': 'a',
    'ă': 'a',
    'ằ': 'a',
    'ắ': 'a',
    'ặ': 'a',
    'ẳ': 'a',
    'ẵ': 'a',
    'è': 'e',
    'é': 'e',
    'ẹ': 'e',
    'ẻ': 'e',
    'ẽ': 'e',
    'ê': 'e',
    'ề': 'e',
    'ế': 'e',
    'ệ': 'e',
    'ể': 'e',
    'ễ': 'e',
    'ì': 'i',
    'í': 'i',
    'ị': 'i',
    'ỉ': 'i',
    'ĩ': 'i',
    'ò': 'o',
    'ó': 'o',
    'ọ': 'o',
    'ỏ': 'o',
    'õ': 'o',
    'ô': 'o',
    'ồ': 'o',
    'ố': 'o',
    'ộ': 'o',
    'ổ': 'o',
    'ỗ': 'o',
    'ơ': 'o',
    'ờ': 'o',
    'ớ': 'o',
    'ợ': 'o',
    'ở': 'o',
    'ỡ': 'o',
    'ù': 'u',
    'ú': 'u',
    'ụ': 'u',
    'ủ': 'u',
    'ũ': 'u',
    'ư': 'u',
    'ừ': 'u',
    'ứ': 'u',
    'ự': 'u',
    'ử': 'u',
    'ữ': 'u',
    'ỳ': 'y',
    'ý': 'y',
    'ỵ': 'y',
    'ỷ': 'y',
    'ỹ': 'y',
    'đ': 'd',
  };

  static String normalize(String value) {
    final lower = value.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_diacriticMap[char] ?? char);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool hasWakePhrase(String text) {
    final normalized = normalize(text);
    final compact = normalized.replaceAll(' ', '');
    const phrases = [
      'alo mimo',
      'a lo mimo',
      'mimo oi',
      'hey mimo',
      'hello mimo',
      'ok mimo',
    ];
    const compactPhrases = [
      'alomimo',
      'mimooi',
      'heymimo',
      'hellomimo',
      'okmimo',
    ];

    return phrases.any(normalized.contains) ||
        compactPhrases.any(compact.contains);
  }

  static bool isExitCommand(String text) {
    final normalized = normalize(text);
    final compact = normalized.replaceAll(' ', '');
    const phrases = [
      'ket thuc',
      'dung lai',
      'thoat',
      'tam biet',
      'goodbye',
      'bye',
      'stop',
      'end call',
      'hang up',
    ];
    const compactPhrases = [
      'ketthuc',
      'dunglai',
      'tambiet',
      'endcall',
      'hangup',
    ];

    return phrases.any(normalized.contains) ||
        compactPhrases.any(compact.contains);
  }

  static VoiceAgentLocale inferLocale(String text) {
    final lower = text.toLowerCase();
    if (RegExp(
      r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]',
    ).hasMatch(lower)) {
      return VoiceAgentLocale.vietnamese;
    }

    final normalized = normalize(text);
    const vietnameseHints = [
      'toi',
      'minh',
      'ban',
      'cho',
      'giup',
      'dat',
      'san',
      'luc',
      'may',
      'mon',
      'nuoc',
      'thuc don',
      'cam on',
      'ket thuc',
      'dung lai',
    ];
    const englishHints = [
      'what',
      'how',
      'can',
      'please',
      'book',
      'court',
      'menu',
      'drink',
      'thanks',
      'thank you',
      'goodbye',
    ];

    if (vietnameseHints.any(normalized.contains)) {
      return VoiceAgentLocale.vietnamese;
    }
    if (englishHints.any(normalized.contains)) {
      return VoiceAgentLocale.english;
    }

    return VoiceAgentLocale.vietnamese;
  }

  static String speechLocaleId(VoiceAgentLocale locale) {
    return switch (locale) {
      VoiceAgentLocale.vietnamese => 'vi_VN',
      VoiceAgentLocale.english => 'en_US',
    };
  }

  static String ttsLocaleId(VoiceAgentLocale locale) {
    return switch (locale) {
      VoiceAgentLocale.vietnamese => 'vi-VN',
      VoiceAgentLocale.english => 'en-US',
    };
  }
}
