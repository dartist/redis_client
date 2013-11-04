part of redis_protocol_transformer;



/// Base class for all Exceptions.
abstract class RedisProtocolTransformerException extends Error implements Exception {

  /// The error message of this exception.
  final String message;

  /// Every subclass can set a base message that will prepend the actual message.
  String _baseMessage;

  RedisProtocolTransformerException([ this.message ]);

  /// Returns the [_baseMessage] with the [message].
  String toString() {
    if (message != null) {
      return "$_baseMessage: $message";
    }
    return _baseMessage;
  }

}

/// This exception is thrown whenever a redis response is incorrect.
class InvalidRedisResponseError extends RedisProtocolTransformerException {

  final String _baseMessage = "Invalid redis response";

  InvalidRedisResponseError(message) : super(message);

}

/// This exception is thrown whenever the redis stream closed unexpectedly
class UnexpectedRedisClosureError extends RedisProtocolTransformerException  {

  final String _baseMessage = "The redis connection closed unexpectedly";

  UnexpectedRedisClosureError(message) : super(message);

}


