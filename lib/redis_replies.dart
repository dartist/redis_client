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
   *
   * If you want to access the data, use [data] which joins these blocks and
   * returns them as one list.
   * Beware that you can only call [data] when the reply is [done].
   */
  List<List<int>> _dataBlocks = [ ];



  /// The joined _dataBlocks.
  List<int> _data;

  /**
   * Returns the complete data of this reply.
   *
   * This can only be called when this reply is [done].
   *
   * In contrast to [_dataBlocks] this strips the trailing CR LF.
   */
  List<int> get data {
    assert(done);

    if (_data == null) {
      // Everything here should work fine, even if [_dataBlocks] is empty.

      int dataSize = _dataBlocks.fold(0, (int prevValue, List dataBlock) => prevValue + dataBlock.length);

      // Remove the trailing CR LF
      _data = new List<int>(dataSize - 2);
      int cursor = 0;

      for (var i = 0; i < _dataBlocks.length; i++) {
        var dataBlock = _dataBlocks[i];

        if (i == _dataBlocks.length - 1) {
          // Last block, so remove CR LF
          dataBlock = new UnmodifiableListView(dataBlock.getRange(0, dataBlock.length - 2));
        }
        _data.setAll(cursor, dataBlock);
        cursor += dataBlock.length;

      }
    }

    return _data;
  }

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
abstract class _OneLineReply extends RedisReply {

  static const int CR = 13;

  static const int LF = 10;

  /**
   * Removes the leading type character and checks if the data contains
   * the ending CR LF characters.
   */
  List<int> consumeData(List<int> data) {
    assert(!done);

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

    for (i = start; i < data.length; i++) {
      char = data[i];

      if (lastChar == CR && char == LF) {
        containedLineEnd = true;
        break;
      }

      lastChar = char;
    }

    // Decrease by one since i++ gets called one time too often if the whole
    // loop runs through.
    if (!containedLineEnd) i--;


    if (start == 0 && i == data.length - 1) {
      // We can just use the whole data object and add it
      _dataBlocks.add(data);
    }
    else {
      // Sublist
      _dataBlocks.add(new UnmodifiableListView(data.getRange(start, i + 1)));
    }

    if (containedLineEnd) _done = true;

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
    if (_line == null) {
      // [data] checks if this reply is [done] and fails if not.
      _line = decodeUtf8(data);
    }
    return _line;
  }

}

class StatusReply extends _OneLineReply {

  /// Returns the status received with this reply.
  String get status => _getLine();

}

class ErrorReply extends _OneLineReply {

  /// Returns the error received with this reply.
  String get error => _getLine();

}

class IntegerReply extends _OneLineReply {

  /// Returns the integer received with this reply.
  int get integer => int.parse(_getLine());

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

