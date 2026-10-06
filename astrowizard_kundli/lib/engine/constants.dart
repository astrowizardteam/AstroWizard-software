const List<String> kSigns = [
  'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo', 'Libra',
  'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces',
];

const List<String> kSignsShort = [
  'Ar', 'Ta', 'Ge', 'Cn', 'Le', 'Vi', 'Li', 'Sc', 'Sg', 'Cp', 'Aq', 'Pi',
];

const List<String> kNakshatras = [
  'Ashwini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra',
  'Punarvasu', 'Pushya', 'Ashlesha', 'Magha', 'Purva Phalguni',
  'Uttara Phalguni', 'Hasta', 'Chitra', 'Swati', 'Vishakha', 'Anuradha',
  'Jyeshtha', 'Mula', 'Purva Ashadha', 'Uttara Ashadha', 'Shravana',
  'Dhanishta', 'Shatabhisha', 'Purva Bhadrapada', 'Uttara Bhadrapada',
  'Revati',
];

/// Sign lords, indexed by sign (0 = Aries).
const List<String> kSignLords = [
  'Mars', 'Venus', 'Mercury', 'Moon', 'Sun', 'Mercury',
  'Venus', 'Mars', 'Jupiter', 'Saturn', 'Saturn', 'Jupiter',
];

const Map<String, String> kPlanetShort = {
  'Sun': 'Su', 'Moon': 'Mo', 'Mars': 'Ma', 'Mercury': 'Me',
  'Jupiter': 'Ju', 'Venus': 'Ve', 'Saturn': 'Sa', 'Rahu': 'Ra', 'Ketu': 'Ke',
};

/// Display order used in tables.
const List<String> kPlanetOrder = [
  'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', 'Rahu', 'Ketu',
];

/// The seven classical planets (no nodes) used by Ashtakavarga and Shadbala.
const List<String> kSeven = [
  'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn',
];

/// Three-letter style abbreviations for chart labels.
const List<String> kNakshatraAbbr = [
  'Ash', 'Bha', 'Kri', 'Roh', 'Mri', 'Ard', 'Pun', 'Pus', 'Asl', 'Mag',
  'PPh', 'UPh', 'Has', 'Chi', 'Swa', 'Vis', 'Anu', 'Jye', 'Mul', 'PAs',
  'UAs', 'Shr', 'Dha', 'Sha', 'PBh', 'UBh', 'Rev',
];

const double kNakshatraSpan = 360.0 / 27;
