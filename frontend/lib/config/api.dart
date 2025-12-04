// Central place to configure backend API endpoint.
// Update this to your deployed Cloud Functions base URL, or override with --dart-define.
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://us-central1-livegreen-bf838.cloudfunctions.net/api');

// The Razorpay public key is provided to the client. For production builds pass
// the value at build time using --dart-define. A test fallback is preserved
// to allow local development when a define is not supplied.
const String razorpayPublicKey = String.fromEnvironment('RAZORPAY_PUBLIC_KEY', defaultValue: 'rzp_test_abc123');

// Optional: Hosted Razorpay Payment Link for donations. When provided, the app
// will open this link in the external browser instead of using the in-app SDK
// for donation flows. Pass at build time with --dart-define.
const String razorpayPaymentLink = String.fromEnvironment('RAZORPAY_PAYMENT_LINK', defaultValue: '');
