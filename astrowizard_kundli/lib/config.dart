/// Link shared by "Share with a friend". Replace it with the direct APK or
/// Play Store link once the app is published.
const String kShareLink = 'https://astrowizard.co.in';

const String kShareMessage =
    'AstroWizard Kundali Software: free Vedic kundli app with charts, dashas, '
    'Shadbala, Panchang and more, works offline.\nDownload: $kShareLink';

/// Where users recharge. They pay there (Razorpay) and receive an activation code.
const String kRechargeUrl = 'https://www.astrowizard.co.in/apprecharge';

/// Secret used to check activation codes. It is NOT stored in the repository:
/// the GitHub workflow passes it at build time (--dart-define=AW_SECRET=...).
const String kActivationSecret = String.fromEnvironment('AW_SECRET');
