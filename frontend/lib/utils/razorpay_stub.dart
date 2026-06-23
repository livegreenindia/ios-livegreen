// Local stub for razorpay_flutter — used while Razorpay SDK is excluded
// from the build. open() immediately fires the error callback so callers
// get a clear failure instead of hanging silently.

class PaymentSuccessResponse {
  final String? paymentId;
  final String? orderId;
  final String? signature;
  PaymentSuccessResponse(this.paymentId, this.orderId, this.signature);
}

class PaymentFailureResponse {
  final int code;
  final String? message;
  PaymentFailureResponse(this.code, this.message);
}

class ExternalWalletResponse {
  final String? walletName;
  ExternalWalletResponse(this.walletName);
}

class Razorpay {
  static const String EVENT_PAYMENT_SUCCESS = 'payment.success';
  static const String EVENT_PAYMENT_ERROR = 'payment.error';
  static const String EVENT_EXTERNAL_WALLET = 'payment.external_wallet';
  static const int PAYMENT_CANCELLED = 0;

  Function? _onError;

  void on(String event, Function handler) {
    if (event == EVENT_PAYMENT_ERROR) _onError = handler;
  }

  void open(Map options) {
    Future.microtask(() => _onError?.call(
          PaymentFailureResponse(1, 'Payment temporarily unavailable. Please update the app.'),
        ));
  }

  void clear() {}
}
