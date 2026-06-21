import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Whether in-app paid/donation flows must be disabled.
///
/// On iOS, App Store Guideline 3.1.1 requires that digital purchases use
/// Apple In-App Purchase. Since the app uses Razorpay (not permitted for
/// digital goods on iOS), all paywalls, premium gating, and the voluntary
/// "Support Us" donation are disabled on iOS — iOS users get every feature
/// free. Android and web are unaffected.
bool get paymentsDisabled => !kIsWeb && Platform.isIOS;
