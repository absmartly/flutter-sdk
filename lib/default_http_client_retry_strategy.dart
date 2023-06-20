import 'dart:io';
import 'dart:math';

class DefaultHTTPClientRetryStrategy  {
  static const int MIN_RETRY_INTERVAL = 5;

  final int maxRetries;
  final int retryIntervalUs;

  DefaultHTTPClientRetryStrategy(this.maxRetries, int maxRetryIntervalMs)
      : retryIntervalUs = max(
            0,
            (2000 * (maxRetryIntervalMs - MIN_RETRY_INTERVAL)) ~/
                (1 << maxRetries));

  // @override
  bool retryRequest(
      {

        HttpResponse? response,
        HttpRequest? request,
      IOException? exception,
      required int execCount,
      }) {
    if(exception != null){
      return execCount <= maxRetries;
    }else{
      return (execCount <= maxRetries) && retryableCodes.contains(response!.statusCode);
    }
  }


  // @override
  Duration getRetryInterval({required HttpResponse response, required int execCount}) {
    return Duration(
        milliseconds: MIN_RETRY_INTERVAL +
            (((1 << (execCount - 1)) * retryIntervalUs) ~/ 1000));
  }

  static final Set<int> retryableCodes = {502, 503}.toSet();
}
