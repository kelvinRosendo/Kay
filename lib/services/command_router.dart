enum LocalCommand {
  youtube('YouTube'),
  spotify('Spotify'),
  chrome('Chrome'),
  settings('configurações'),
  time('horário'),
  date('data'),
  weekday('dia da semana'),
  tomorrow('amanhã');

  const LocalCommand(this.label);
  final String label;
}

class CommandRouter {
  static LocalCommand? parse(String text) {
    var value = text.toLowerCase();
    const accents = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c',
    };
    accents.forEach((from, to) => value = value.replaceAll(from, to));
    value = value
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    value = value.replaceFirst(RegExp(r'^(kay|kai|kei) '), '');
    value = value
        .replaceFirst(RegExp(r'^por favor '), '')
        .replaceFirst(RegExp(r' por favor$'), '')
        .trim();

    // ── Time ──────────────────────────────────────────────────────
    if (RegExp(
      r'^(que horas sao|que hora e|qual e a hora|qual a hora|'
      r'me diga as horas|me diz as horas|me diga o horario)$',
    ).hasMatch(value)) {
      return LocalCommand.time;
    }

    // ── Date ──────────────────────────────────────────────────────
    if (RegExp(
      r'^(qual e a data de hoje|qual a data de hoje|'
      r'que dia e hoje|que dia e de hoje|'
      r'qual e a data|que data e hoje|me diga a data|me diz a data)$',
    ).hasMatch(value)) {
      return LocalCommand.date;
    }

    // ── Weekday ───────────────────────────────────────────────────
    if (RegExp(
      r'^(que dia da semana e hoje|que dia da semana e|'
      r'qual e o dia da semana|qual o dia da semana|'
      r'que dia e da semana|me diz o dia da semana|me diga o dia da semana)$',
    ).hasMatch(value)) {
      return LocalCommand.weekday;
    }

    // ── Tomorrow ──────────────────────────────────────────────────
    if (RegExp(
      r'^(qual e o dia de amanha|qual o dia de amanha|'
      r'que dia e amanha|que dia e de amanha|'
      r'qual e amanha|me diz amanha|me diga amanha)$',
    ).hasMatch(value)) {
      return LocalCommand.tomorrow;
    }

    // ── App opening ───────────────────────────────────────────────
    final match = RegExp(
      r'^(?:abrir|abre|abra)(?: o| a| as| os)? '
      r'(youtube|you tube|spotify|chrome|google chrome|'
      r'configuracoes|configuracao|ajustes)$',
    ).firstMatch(value);
    return switch (match?.group(1)) {
      'youtube' || 'you tube' => LocalCommand.youtube,
      'spotify' => LocalCommand.spotify,
      'chrome' || 'google chrome' => LocalCommand.chrome,
      'configuracoes' || 'configuracao' || 'ajustes' => LocalCommand.settings,
      _ => null,
    };
  }

  static String timeReply(DateTime now) =>
      'Agora são ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}.';

  static String dateReply(DateTime now) {
    final day = now.day;
    final month = _monthName(now.month);
    final year = now.year;
    return 'Hoje é $day de $month de $year.';
  }

  static String weekdayReply(DateTime now) {
    final dayName = _weekdayName(now.weekday);
    final day = now.day;
    final month = _monthName(now.month);
    return 'Hoje é $dayName, $day de $month.';
  }

  static String tomorrowReply(DateTime now) {
    final tomorrow = now.add(const Duration(days: 1));
    final dayName = _weekdayName(tomorrow.weekday);
    final day = tomorrow.day;
    final month = _monthName(tomorrow.month);
    return 'Amanhã é $dayName, $day de $month.';
  }

  static String _monthName(int month) => switch (month) {
        1 => 'janeiro',
        2 => 'fevereiro',
        3 => 'março',
        4 => 'abril',
        5 => 'maio',
        6 => 'junho',
        7 => 'julho',
        8 => 'agosto',
        9 => 'setembro',
        10 => 'outubro',
        11 => 'novembro',
        12 => 'dezembro',
        _ => 'mês $month',
      };

  static String _weekdayName(int weekday) => switch (weekday) {
        1 => 'segunda-feira',
        2 => 'terça-feira',
        3 => 'quarta-feira',
        4 => 'quinta-feira',
        5 => 'sexta-feira',
        6 => 'sábado',
        7 => 'domingo',
        _ => 'dia $weekday',
      };
}
