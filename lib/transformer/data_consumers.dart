part of redis_protocol_transformer;



/**
 * Base class for data block consumers used by [RedisReply]s to extract any kind
 * of data.
 */
abstract class _DataConsumer {

  static const int CR = 13;

  static const int LF = 10;

  bool _done = false;

  /// Whether the whole data has been consumed.
  bool get done => _done;


  /**
   * This is a list of the actual data blocks of the reply.
   *
   * Every time [consumeData] is called it adds a dataBlock here.
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

      bool lastBlockOnlyLF = false;
      if (_dataBlocks.last.length == 1 && _dataBlocks.last.first == LF) {
        lastBlockOnlyLF = true;
      }


      int blocksToGoThrough = lastBlockOnlyLF ? _dataBlocks.length - 1 :  _dataBlocks.length;

      for (var i = 0; i < blocksToGoThrough; i++) {
        var dataBlock = _dataBlocks[i];

        if (i == blocksToGoThrough - 1) {
          // Last block, so remove CR LF (or only CR if the last LF block has been skipped)
          dataBlock = new UnmodifiableListView(dataBlock.getRange(0, dataBlock.length - (lastBlockOnlyLF ? 1 : 2)));
        }
        _data.setAll(cursor, dataBlock);
        cursor += dataBlock.length;

      }
    }

    return _data;
  }


  /// Holds the unconsumed data, if any.
  List<int> unconsumedData;

  void consumeData(List<int> data);

}



/**
 * Class used by [RedisReply]s to get a single line out of data chunks.
 */
class _OneLineDataConsumer extends _DataConsumer {


  /// Whether the start symbol has already been transmitted.
  bool _receivedStartChar = false;

  /**
   * Consumes any number of data blocks.
   *
   * When the end of the line has been found, it returns the uncosumed data and
   * sets [done] to true.
   *
   * Can't be called again, once the line is complete.
   */
  void consumeData(List<int> data) {

    assert(!done);

    int start = 0;
    int lastChar = null;

    if (!_receivedStartChar) {
      // This is the first time called so skip the first byte.
      start = 1;
      _receivedStartChar = true;
      if (data.length == 1) {
        // Well, this data block contained only the initial reply type char.
        return;
      }
    }
    else {
      lastChar = _dataBlocks.isEmpty ? null : _dataBlocks.last.last;
    }

    var i, char, containedLineEnd = false;

    for (i = start; i < data.length; i++) {
      char = data[i];

      if (lastChar == _DataConsumer.CR && char == _DataConsumer.LF) {
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

    if (i != data.length - 1) {
      // There is unconsumed data.
      unconsumedData = new UnmodifiableListView(data.getRange(i + 1, data.length));
    }

  }

}


/**
 * Class used by [RedisReply]s to get a fixed length of bytes out of data chunks.
 */
class _BytesDataConsumer extends _DataConsumer {


  /**
   *  The byteLength of this data chunk.
   *
   *  Note that this length does **not** include the trailing CR LF characters.
   */
  final int byteLength;

  _BytesDataConsumer(this.byteLength);


  /// Returns the size of all data blocks.
  int get _dataBlocksLength => _dataBlocks.fold(0, (int prev, List<int> block) => prev + block.length);

  /**
   * Consumes any number of data blocks.
   *
   * When the end of the line has been found, it returns the uncosumed data and
   * sets [done] to true.
   *
   * Can't be called again, once the line is complete.
   */
  void consumeData(List<int> data) {

    assert(!done);


    var byteLengthWithNewline = byteLength + 2,
        totalBlocksLength = _dataBlocksLength,
        afterBlocksLength = data.length + totalBlocksLength;

    if (afterBlocksLength <= byteLengthWithNewline) {
      _dataBlocks.add(data);

      if (afterBlocksLength == byteLengthWithNewline) {
        _done = true;
      }
    }
    else {
      // TODO: add a subset of it.
      _dataBlocks.add(new UnmodifiableListView(data.getRange(0, byteLengthWithNewline - totalBlocksLength)));
      unconsumedData = new UnmodifiableListView(data.getRange(byteLengthWithNewline - totalBlocksLength, data.length));
      _done = true;
    }

  }

}
