/// House significations used by the Dasha Guide.
///
/// Based on the standard bhava karakatvas of classical texts (Brihat Parashara
/// Hora Shastra "Bhava phala", Phaladeepika, Saravali, B.V. Raman's Hindu
/// Predictive Astrology), written in the app's own words. To match another
/// other wording, edit the keyword lists below — nothing else needs changing.
class HouseInfo {
  final String name; // Sanskrit name
  final String theme; // one-line summary
  final List<String> keywords; // most important first
  final List<String> kinds; // kendra, trikona, dusthana, upachaya, maraka
  const HouseInfo(this.name, this.theme, this.keywords, this.kinds);
}

const List<HouseInfo> kHouseInfo = [
  HouseInfo('Tanu', 'Self and body', [
    'self, personality, identity', 'body, health, vitality', 'appearance, head',
    'fresh starts, initiative', 'fame, general life direction',
  ], ['kendra', 'trikona']),
  HouseInfo('Dhana', 'Wealth and family', [
    'accumulated wealth, savings', 'family, kutumba', 'speech, voice',
    'food, face, right eye', 'early learning, values', 'resources one can hold',
  ], ['maraka']),
  HouseInfo('Sahaja', 'Courage and effort', [
    'courage, own effort', 'younger siblings', 'skills, arts, writing',
    'short journeys, communication', 'hands, shoulders, ears', 'initiative to act',
  ], ['upachaya']),
  HouseInfo('Sukha', 'Home and comfort', [
    'mother, home', 'property, land, vehicles', 'inner peace, happiness',
    'basic education', 'chest, heart', 'domestic comfort',
  ], ['kendra']),
  HouseInfo('Putra', 'Intelligence and children', [
    'children, progeny', 'intelligence, higher mind', 'creativity, romance',
    'speculation, gains by luck', 'mantra, past-life merit (purva punya)', 'advisory roles',
  ], ['trikona']),
  HouseInfo('Ripu', 'Enemies and service', [
    'disease, illness', 'debts, loans', 'enemies, competition, litigation',
    'daily work, service, employment', 'maternal uncle, pets', 'obstacles to be overcome',
  ], ['dusthana', 'upachaya']),
  HouseInfo('Kalatra', 'Spouse and partnership', [
    'spouse, marriage', 'business partnerships', 'dealings with the public',
    'foreign trade and travel', 'desires, sexual life', 'contracts, negotiation',
  ], ['kendra', 'maraka']),
  HouseInfo('Ayu', 'Longevity and the hidden', [
    'longevity, sudden events', 'transformation, crises', 'inheritance, in-laws\' money, insurance',
    'chronic or hidden illness, accidents', 'occult, research, secrets', 'delays and obstacles',
  ], ['dusthana']),
  HouseInfo('Dharma', 'Fortune and dharma', [
    'fortune, luck, grace', 'father, guru, mentors', 'religion, dharma, ethics',
    'higher education, long journeys', 'merit from past deeds', 'philosophy, teaching',
  ], ['trikona']),
  HouseInfo('Karma', 'Career and status', [
    'career, profession', 'status, reputation, authority', 'government, public life',
    'actions, achievements', 'father (some schools)', 'knees, ambitions',
  ], ['kendra', 'upachaya']),
  HouseInfo('Labha', 'Gains and fulfilment', [
    'income, profits, gains', 'fulfilment of desires', 'elder siblings, friends, networks',
    'social circle, groups', 'ankles, recovery of losses', 'rewards for earlier effort',
  ], ['upachaya']),
  HouseInfo('Vyaya', 'Expenses and release', [
    'expenses, losses', 'foreign lands, distant places', 'isolation, hospitals, prisons',
    'sleep, bed pleasures', 'charity, spending on others', 'moksha, spiritual release',
  ], ['dusthana']),
];

String kindsText(List<String> k) => k.join(', ');

/// How the lower lord's house stands from the greater lord's house (1 = same house).
const Map<int, String> kFromMd = {
  1: 'Same house: the two lords share one house; their themes are fused and results are concentrated.',
  2: 'Lower lord is 2nd from the greater lord: resources and family support flow into its themes.',
  3: 'Lower lord is 3rd from the greater lord: needs effort and initiative; results come by own courage.',
  4: 'Lower lord is 4th from the greater lord (kendra): stable, supportive base; steady results.',
  5: 'Lower lord is 5th from the greater lord (trikona): harmonious, creative and fortunate flow.',
  6: 'Lower lord is 6th from the greater lord: friction, competition, health or debt issues colour the results.',
  7: 'Lower lord is 7th from the greater lord (kendra, opposition): a reaction or partnership-type interplay.',
  8: 'Lower lord is 8th from the greater lord: strain, sudden turns and delays; transformation of that field.',
  9: 'Lower lord is 9th from the greater lord (trikona): fortunate, guided by luck and mentors.',
  10: 'Lower lord is 10th from the greater lord (kendra): action oriented; visible achievements in that field.',
  11: 'Lower lord is 11th from the greater lord: gains and fulfilment of desires of that field.',
  12: 'Lower lord is 12th from the greater lord: expenses, drain or withdrawal from that field.',
};

/// The reverse view (greater lord house counted from the lower lord house): 6/8, 2/12 etc.
String axisText(int mdFromAd) {
  switch (mdFromAd) {
    case 6:
    case 8:
      return 'The two houses are in a 6/8 relation (shadashtaka): the two lords pull against each other.';
    case 2:
    case 12:
      return 'The two houses are in a 2/12 axis (dwirdwadasha): mixed results, give and take.';
    case 5:
    case 9:
      return 'The two houses are in a 5/9 axis (trikona): mutually supportive.';
    case 4:
    case 10:
      return 'The two houses are in a 4/10 axis (kendra): practical cooperation.';
    case 3:
    case 11:
      return 'The two houses are in a 3/11 axis: effort leads to gain.';
    case 7:
      return 'The two houses face each other (1/7 axis): a push-pull, dependent on each other.';
    default:
      return '';
  }
}
