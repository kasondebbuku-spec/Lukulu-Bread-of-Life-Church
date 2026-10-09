class DailyVerse {
  const DailyVerse(this.text, this.reference);

  final String text;
  final String reference;
}

/// Public-domain (KJV) verses rotated one per calendar day.
const dailyVerses = [
  DailyVerse(
      'This is the day which the LORD hath made; we will rejoice and be glad in it.',
      'Psalm 118:24'),
  DailyVerse(
      'I am the bread of life: he that cometh to me shall never hunger; and he that believeth on me shall never thirst.',
      'John 6:35'),
  DailyVerse(
      'Trust in the LORD with all thine heart; and lean not unto thine own understanding.',
      'Proverbs 3:5'),
  DailyVerse('I can do all things through Christ which strengtheneth me.',
      'Philippians 4:13'),
  DailyVerse('The LORD is my shepherd; I shall not want.', 'Psalm 23:1'),
  DailyVerse(
      'Come unto me, all ye that labour and are heavy laden, and I will give you rest.',
      'Matthew 11:28'),
  DailyVerse(
      'God is our refuge and strength, a very present help in trouble.',
      'Psalm 46:1'),
  DailyVerse('Thy word is a lamp unto my feet, and a light unto my path.',
      'Psalm 119:105'),
  DailyVerse(
      'Enter into his gates with thanksgiving, and into his courts with praise: be thankful unto him, and bless his name.',
      'Psalm 100:4'),
  DailyVerse(
      'Fear thou not; for I am with thee: be not dismayed; for I am thy God.',
      'Isaiah 41:10'),
  DailyVerse(
      'And let us not be weary in well doing: for in due season we shall reap, if we faint not.',
      'Galatians 6:9'),
  DailyVerse(
      'Every man according as he purposeth in his heart, so let him give; not grudgingly, or of necessity: for God loveth a cheerful giver.',
      '2 Corinthians 9:7'),
  DailyVerse(
      'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.',
      'John 3:16'),
  DailyVerse(
      'But they that wait upon the LORD shall renew their strength; they shall mount up with wings as eagles.',
      'Isaiah 40:31'),
  DailyVerse(
      'Rejoice evermore. Pray without ceasing. In every thing give thanks.',
      '1 Thessalonians 5:16-18'),
  DailyVerse(
      'And we know that all things work together for good to them that love God.',
      'Romans 8:28'),
];

DailyVerse verseForDate(DateTime date) {
  final dayOfYear = date.difference(DateTime(date.year)).inDays;
  return dailyVerses[dayOfYear % dailyVerses.length];
}
