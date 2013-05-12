part of redis_protocol_transformer;

/**
 * Base class for redis replies.
 *
 * Every time a new redis reply is received, this class is instantiated,
 * and returned with the corresponding data.
 */
abstract class RedisReply {

  /// A reply type
  static const int STATUS = RedisProtocolTransformer.PLUS;

  /// A reply type
  static const int ERROR = RedisProtocolTransformer.DASH;

  /// A reply type
  static const int INTEGER = RedisProtocolTransformer.COLON;

  /// A reply type
  static const int BULK = RedisProtocolTransformer.DOLLAR;

  /// A reply type
  static const int MULTI_BULK = RedisProtocolTransformer.ASTERIX;

  /// A list of all defined types.
  static const List<int> TYPES = const [ STATUS, ERROR, INTEGER, BULK, MULTI_BULK ];


  /**
   * This is a list of the actual data blocks of the reply.
   *
   * Every time [_consumeData] is called it adds a dataBlock here.
   *
   * The datablocks are without the leading type character and closing delimiter.
   */
  List<List<int>> _dataBlocks = [ ];

  /**
   * Gets called with the data block and consumes as much as it needs.
   *
   * If it consumes all of the data (either because some data is still missing
   * or because all of the data has been used as a reply) it should return null.
   *
   * This function has to set [done] to true if all data for this reply has been
   * provided.
   *
   * If it's the first time this [RedisReply] receives that, it must contain
   * the leading type character.
   */
  List<int> _consumeData(List<int> newData);

  bool _done = false;

  /// Specifies if this reply has been fully received.
  bool get done => _done;

}


/**
 * All replies that can only consist of one line extend this class.
 *
 * The line is always ended by CR LF.
 */
class _OneLineReply extends RedisReply {

  static const int CR = 13;

  static const int LF = 10;

  /**
   * Removes the leading type character and checks if the data contains
   * the ending CR LF characters.
   */
  List<int> consumeData(List<int> data) {
    int start = 0;
    int lastChar = null;

    if (_dataBlocks.isEmpty) {
      // This is the first time called so skip the first byte.
      start = 1;
    }
    else {
      lastChar = _dataBlocks.last.last;
    }

    var i, char, containedLineEnd = false;

    for (i = start; i < data.length; i ++) {
      char = data[i];

      if (lastChar == CR && char == LF) {
        containedLineEnd = true;
        break;
      }
    }

    if (start == 0 && i == data.length - 1) {
      // We can just use the whole data object and add it
      _dataBlocks.add(data);
    }
    else {
      // Sublist
      _dataBlocks.add(new UnmodifiableListView(data.getRange(start, i)));
    }

    if (containedLineEnd) {
      _done = true;
      // TODO: actually handle it.
    }

    if (i == data.length - 1) {
      // All data has been consumed
      return null;
    }
    else {
      return new UnmodifiableListView(data.getRange(i + 1, data.length));
    }

  }


  String _line;

  /// Returns the line of this reply.
  String _getLine() {
    assert(done);

    if (_line == null) {
      // TODO: Actually return it.
//      _line = new String.fromCharCodes(_data);
    }
    return _line;
  }

}

class StatusReply extends _OneLineReply {


  String _status;

  /// Returns the status received with this reply.
  String get status => _getLine();

}

class ErrorReply extends _OneLineReply {

}

class IntegerReply extends _OneLineReply {

}

class BulkReply extends RedisReply {

}


/**
 * This class differs a bit from the oder RedisReplies in that it actually
 * holds a list of mulitple [BulkReply]s.
 */
class MultiBulkReply extends RedisReply {

  /// Holds a list of [BulkReply] objects.
  List<BulkReply> bulkReplies;

}

