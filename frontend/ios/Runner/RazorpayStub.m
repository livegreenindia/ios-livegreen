#import <Flutter/Flutter.h>

// Stub satisfies GeneratedPluginRegistrant's reference to RazorpayFlutterPlugin
// without linking or embedding the Razorpay binary payment frameworks.
//
// Razorpay is a third-party payment gateway that cannot be used for iOS
// in-app purchases — the App Store requires Apple IAP (Guideline 3.1.1).
// Having the Razorpay SDK in the iOS binary also triggers rejection under
// Guideline 2.5.4 (alternative payment software). Payments are hidden on
// iOS via paymentsDisabled=true in platform_payments.dart, so this stub
// is never invoked at runtime.
@interface RazorpayFlutterPlugin : NSObject <FlutterPlugin>
@end

@implementation RazorpayFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    // No-op: Razorpay is disabled on iOS.
}
@end
