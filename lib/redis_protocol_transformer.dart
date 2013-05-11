
import "dart:async";


/**
 * Base class for redis replies.
 *
 * Every time a new redis reply is received, this class is instantiated,
 * and returned with the corresponding data.
 */
abstract class RedisReply {

  /// A reply type
  static final int STATUS = RedisProtocolTransformer.PLUS;

  /// A reply type
  static final int ERROR = RedisProtocolTransformer.DASH;

  /// A reply type
  static final int INTEGER = RedisProtocolTransformer.COLON;

  /// A reply type
  static final int BULK = RedisProtocolTransformer.DOLLAR;

  /// A reply type
  static final int MULTI_BULK = RedisProtocolTransformer.ASTERIX;

  /// A list of all defined types.
  static final List<int> TYPES = [ STATUS, ERROR, INTEGER, BULK, MULTI_BULK ];


}


class StatusReply extends RedisReply {

}

class ErrorReply extends RedisReply {

}

class IntegerReply extends RedisReply {

}

class BulkReply extends RedisReply {

}

class MultiBulkReply extends RedisReply {

}



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


/**
 * The [RedisProtocolTransformer] transforms a redis stream into [RedisReply]
 * objects.
 * For a documentation on the redis protocol, please view the
 * [redis protocol documentation](http://redis.io/topics/protocol).
 */
class RedisProtocolTransformer extends StreamEventTransformer<List<int>, RedisReply> {

  static final int CR = 13;
  static final int LF = 10;

  /// Charcode for status replies
  static final int PLUS = 43;

  /// Charcode for error replies
  static final int DASH = 45;

  /// Charcode for integer replies
  static final int COLON = 58;

  /// Charcode for bulk replies
  static final int DOLLAR = 36;

  /// Charcode for multi bulk replies
  static final int ASTERIX = 42;

  /**
   * If the transformer has alrady received data, this will hold the reply type.
   *
   * Can be any of [RedisReply.STATUS], [RedisReply.ERROR], [RedisReply.INTEGER], [RedisReply.BULK], [RedisReply.MULTI_BULK]
   */
  int _currentReplyType;

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

    if (_currentReplyType == null) {
      // This is a fresh RedisReply. How exciting!
      int replyType = data.first;

      if (!RedisReply.TYPES.contains(replyType)) {
        return this.handleError(new InvalidRedisResponseError("The type character was incorrect (${_charCodeToString(replyType)}."), output);
      }

      _currentReplyType = replyType;

      // TODO: If the reply type is Status, Error or String, check if the CRLF
      // terminator has been submitted. If yes, create the RedisReply and
      // add it.

      // TODO: Otherwise, Check if the data equals or exceeds the expected number
      // of bytes.

    }
    else {
      // Continuing a reply.

      // TODO: If it's a Status, Error or String reply, check if the CRLF is in
      // the new data set. Do nothing if not.

      // TODO: Otherwise check if enough data has been submitted.
    }
  }

  void handleError(Error error, EventSink<RedisReply> output) {
    output.addError(error);
  }

  void handleDone(EventSink<RedisReply> output) {
    // TODO: Check if there is still data that can form a RedisReply.
    output.close();
  }
}