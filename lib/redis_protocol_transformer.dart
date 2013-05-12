library redis_protocol_transformer;


import "dart:async";
import "dart:collection";
import "dart:typed_data";

part 'redis_replies.dart';




/// Base class for all Exceptions.
abstract class RedisProtocolTransformerException extends Error {

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

}

/// This exception is thrown whenever the redis stream closed unexpectedly
class UnexpectedRedisClosureError extends RedisProtocolTransformerException {

  final String _baseMessage = "The redis connection closed unexpectedly";

}


/**
 * The [RedisProtocolTransformer] transforms a redis stream into [RedisReply]
 * objects.
 * For a documentation on the redis protocol, please view the
 * [redis protocol documentation](http://redis.io/topics/protocol).
 */
class RedisProtocolTransformer extends StreamEventTransformer<List<int>, RedisReply> {

  /// Charcode for status replies
  static const int PLUS = 43;

  /// Charcode for error replies
  static const int DASH = 45;

  /// Charcode for integer replies
  static const int COLON = 58;

  /// Charcode for bulk replies
  static const int DOLLAR = 36;

  /// Charcode for multi bulk replies
  static const int ASTERIX = 42;

  /**
   * If the transformer has alrady received data, this will hold the [RedisReply].
   */
  RedisReply _currentReply;

  /// Converts a list of char codes to a String
  String _charCodesToString(List<int> bytes) => new String.fromCharCodes(bytes);

  /// Converts a char code to a String
  String _charCodeToString(int byte) => new String.fromCharCode(byte);

  /**
   * Actually handles the incoming data and adds [RedisReply] objects to the
   * sink when they're ready.
   */
  void handleData(List<int> data, EventSink<RedisReply> output) {

    // I'm not entirely sure this is necessary, but better be safe.
    if (data.length == 0) return;

    if (_currentReply == null) {
      // This is a fresh RedisReply. How exciting!
      int replyType = data.first;

      // Check if it's a valid replyType character
      if (!RedisReply.TYPES.contains(replyType)) {
        this.handleError(new InvalidRedisResponseError("The type character was incorrect (${_charCodeToString(replyType)})."), output);
        return;
      }

      // Now instantiate the correct RedisReply
      switch (replyType) {
        case RedisReply.STATUS:
          _currentReply = new StatusReply();
          break;
        default: throw new UnimplementedError("This Redis reply type is not yet implemented");
      }
    }

    List<int> unconsumedData = _currentReply._consumeData(data);

    // Make sure that unconsumedData can't be returned unless the reply is actually done.
    assert(unconsumedData == null || _currentReply.done);

    if (_currentReply.done) {
      // Reply is done!
      output.add(_currentReply);
      _currentReply = null;
      if (unconsumedData != null && !unconsumedData.isEmpty) {
        handleData(unconsumedData, output);
      }
    }
  }

  /**
   * Closes the [EventSink] and adds an error before if there was some
   * incomplete data
   */
  void handleDone(EventSink<RedisReply> output) {

    if (_currentReply != null) {
      // Apparently some data has already been sent, but the stream is done.
      this.handleError(new UnexpectedRedisClosureError("Some data has already been sent but was not complete."), output);
    }

    output.close();
  }
}