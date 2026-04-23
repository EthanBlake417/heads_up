class WordFilter {
  static const Set<String> _blocklist = {
    // Strong profanity
    'fuck', 'fucking', 'fucker', 'fucked', 'fucks', 'fuckface', 'fuckhead',
    'motherfucker', 'motherfucking', 'clusterfuck',
    'shit', 'shitting', 'shitter', 'bullshit', 'horseshit', 'dipshit',
    'asshole', 'assholes', 'asshat', 'jackass',
    'bitch', 'bitches', 'bitching', 'son of a bitch',
    'bastard', 'bastards',
    'goddamn', 'goddammit',
    'pissed off',
    'cunt', 'cunts',
    'whore', 'whores',
    'slut', 'sluts',
    // Slurs
    'faggot', 'fag', 'dyke',
    'retard', 'retarded',
    // Sexual body parts (explicit)
    'penis', 'penises',
    'vagina', 'vaginas', 'vulva',
    'clitoris', 'clit',
    'anus', 'rectum',
    'scrotum', 'testicles',
    'nipple', 'nipples',
    'tits', 'titties', 'titty',
    'boobs', 'boob', 'boobies',
    'boner', 'erection',
    'balls', 'nutsack',
    // Sexual acts / explicit
    'sex', 'sexy', 'sexual', 'sexuality',
    'porn', 'porno', 'pornography', 'pornographic',
    'nude', 'nudity', 'naked',
    'masturbate', 'masturbation', 'masturbating',
    'orgasm', 'orgasms',
    'ejaculate', 'ejaculation', 'ejaculating',
    'blowjob', 'blow job',
    'handjob', 'hand job',
    'anal sex',
    'cum', 'cumshot', 'creampie',
    'threesome', 'gangbang', 'orgy',
    'fetish', 'fetishes',
    'horny',
    'rape', 'rapist', 'raping',
    'incest',
    'pedophile', 'pedophilia', 'pedophilic',
    // Adult industry
    'dildo', 'vibrator', 'buttplug',
    'stripper', 'strippers', 'strip club',
    'prostitute', 'prostitution', 'prostituting',
    'brothel', 'escort service',
    'erotic', 'erotica',
    'jerkoff', 'jerk off', 'jerk-off',
    'wank', 'wanker', 'wanking',
    'fingering',
    'fisting',
  };

  // Only substring-match terms that have near-zero false positives
  static const Set<String> _substringBlocklist = {
    'nigger', 'nigga', 'pedophil',
  };

  static bool isInappropriate(String word) {
    final lower = word.toLowerCase().trim();
    if (_blocklist.contains(lower)) return true;
    for (final sub in _substringBlocklist) {
      if (lower.contains(sub)) return true;
    }
    return false;
  }
}
