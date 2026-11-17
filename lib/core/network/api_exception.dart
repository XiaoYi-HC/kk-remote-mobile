class ApiException implements Exception {
  ApiException(this.message, {this.code = -1, this.requestId, this.statusCode});

  final String message;
  final int code;
  final String? requestId;
  final int? statusCode;

  bool get isUnauthorized => code == 1002 || statusCode == 401;
  bool get isNetworkError => code == -2;

  @override
  String toString() => message;
}

class NetworkUnavailableException extends ApiException {
  NetworkUnavailableException([super.message = '网络连接不可用，请检查网络后重试'])
      : super(code: -2);
}
