class SessionExpiredException implements Exception {
  const SessionExpiredException();
}

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.isNetworkError = false,
    this.isTimeout = false,
    this.preservesDraft = false,
  });

  final String message;
  final int? statusCode;
  final int? code;
  final bool isNetworkError;
  final bool isTimeout;
  final bool preservesDraft;

  bool get isUnauthorized => statusCode == 401 || code == 401;
  bool get isRetryable =>
      isNetworkError || isTimeout || (statusCode != null && statusCode! >= 500);

  @override
  String toString() => message;
}
