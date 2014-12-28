part of redis_protocol_transformer;


/// Responsible for transformation from stream of int to stream of RedisReply
class RedisStreamTransformerHandler {

  StreamTransformer createTransformer() =>
    new StreamTransformer.fromHandlers(handleData: handleData,
        handleError: handleError, handleDone: handleDone);

  void handleDone(EventSink<RedisReply> output) {

    if (_consumer != null) {
      var error = new UnexpectedRedisClosureError("Some data has already been sent but was not complete.");
      // Apparently some data has already been sent, but the stream is done.
      handleError(error, error.stackTrace, output);
    }

    output.close();
  }

  void handleError(Object error, StackTrace stackTrace, EventSink<RedisReply> sink) {
    sink.addError(error, stackTrace);
  }

  void handleData(List<int> data, EventSink<RedisReply> output) {
    // I'm not entirely sure this is necessary, but better be safe.
    if (data.length == 0) return;

    final int end = data.length;
    var i = 0;
    while(i < end) {
      if(_consumer == null) {
        try {
          _consumer = _makeRedisConsumer(data[i++]);
        }
        on RedisProtocolTransformerException catch (e) {
          handleError(e, e.stackTrace, output);
        }
      } else {
        i = _consumer.consume(data, i, end);
        if(_consumer.done) {
          output.add(_consumer.makeReply());
          _consumer = null;
        }
      }
    }
  }

  /// The current consumer
  _RedisConsumer _consumer;
}

final int _CR = 13;
final int _LF = 10;

const int _STATUS = 43;
const int _ERROR = 45;
const int _INTEGER = 58;
const int _BULK = 36;
const int _MULTI_BULK = 42;

/// Establishes base for the consumers of redis data
///
/// The pattern for the consume method is indexed base, meaning consumers are
/// supplied a (start, end] on which to work and they return the index of the
/// next datum to be consumed.
abstract class _RedisConsumer {

  /// consume data from start index up to end (exclusive) index returning the
  /// next index to be consumed if done
  int consume(List<int> data, int start, int end);

  // Create RedisReply from consumed data (requires done == true)
  RedisReply makeReply();

  bool get done;

  List<int> get data {
    assert(done);

    if(_data == null) {
      final dataSize = _dataBlocks.fold(0, (int prevValue, List dataBlock) =>
          prevValue + dataBlock.length);
      if(dataSize == 0) {
        return _data;
      } else {
        _data = new List<int>(dataSize - 2);
        var blocksNeeded = _dataBlocks.length;
        var ignoredCharacters = 2;
        if(_dataBlocks.last.length == 1) {
          assert(_dataBlocks.last.last == _LF);
          ignoredCharacters--;
          blocksNeeded--;
          assert(_dataBlocks[blocksNeeded-1].last == _CR);
        }

        var stringIndex = 0;
        for(var blockIndex=0; blockIndex < blocksNeeded; blockIndex++) {
          final currentBlock = _dataBlocks[blockIndex];
          bool isLastBlock = blockIndex == blocksNeeded - 1;
          final charsToTake = currentBlock.length - (isLastBlock? ignoredCharacters:0);

          _data.setAll(stringIndex,
              isLastBlock?
              currentBlock.take(currentBlock.length - ignoredCharacters) :
              currentBlock);

          stringIndex += charsToTake;
        }
      }
    }
    return _data;
  }

  /// Blocks of data consumed
  final List<List<int>> _dataBlocks = [];

  /// The joined _dataBlocks - lazy initilialized to join via `get data` call
  /// which at that point strips the CR,LF
  List<int> _data;

}

/// Consumes a single line of data
abstract class _LineConsumer extends _RedisConsumer {

  int consume(List<int> data, final int start, final int end) {
    assert(start < end);
    ///////////////////////////////////////////////////////////////////////////
    // Iterate looking for CR,LF to end the line. If we have data already, use
    // the last character saved as check for CR in CR,LF. Otherwise start at
    // beginning of data
    ///////////////////////////////////////////////////////////////////////////
    bool haveSome = !_dataBlocks.isEmpty;

    var prevChar = haveSome? _dataBlocks.last.last : data[start];
    int current = haveSome? start : start + 1;

    for(; current < end; current++) {
      final nextChar = data[current];
      if(prevChar == _CR && nextChar == _LF) {
        _done = true;
        current++;
        break;
      }
      prevChar = nextChar;
    }

    _dataBlocks.add(new UnmodifiableListView(data.getRange(start, current)));

    // we've advanced and either are done or ran out
    assert(current > start && (done || current == end));

    return current;
  }

  String get line => _line == null? (_line = UTF8.decode(data)) : _line;
  bool get done => _done;

  /// The line data as String
  String _line;
  /// Done reading the single line
  bool _done = false;
}

/// Consumes the bulk type redis reply
class _BulkConsumer extends _RedisConsumer {
  int consume(List<int> data, final int start, final int end) {
    assert(start < end);

    int current = start;
    if(_lengthRequired == null) {
      current = _lineConsumer.consume(data, current, end);
      if(_lineConsumer.done) {
        final specifiedLength =
          int.parse(new String.fromCharCodes(_lineConsumer.data));
        if(specifiedLength == -1) {
          _lengthRequired = 0;
        } else {
          _lengthRequired = 2 + specifiedLength;
        }
      }
    } else {
      final needed = _lengthRequired - _lengthRead;
      final desiredEnd = start + needed;
      final takeTo = min(desiredEnd, end);
      _dataBlocks.add(new UnmodifiableListView(data.getRange(start, takeTo)));
      _addToLength(takeTo - start);
      current = takeTo;
    }

    if(current < end && !done) {
      current = consume(data, current, end);
    }

    // we've advanced and either are done or ran out
    assert(current > start && (done || current == end));

    return current;
  }

  get done => _lengthRead == _lengthRequired;

  RedisReply makeReply() => new BulkReply(data);

  _addToLength(int additional) {
    _lengthRead += additional;
    assert(_lengthRead <= _lengthRequired);
  }

  _LineConsumer _lineConsumer = new _IntegerConsumer();
  int _lengthRead = 0;
  int _lengthRequired;
}


class _StatusConsumer extends _LineConsumer {
  RedisReply makeReply() => new StatusReply(line);
}

class _ErrorConsumer extends _LineConsumer {
  RedisReply makeReply() => new ErrorReply(line);
}

class _IntegerConsumer extends _LineConsumer {
  RedisReply makeReply() => new IntegerReply(int.parse(line));
}

class _MultiBulkConsumer extends _RedisConsumer {

  int consume(List<int> data, final int start, final int end) {
    assert(start < end);

    int current = start;
    if(_replies == null) {
      current = _lineConsumer.consume(data, current, end);
      if(_lineConsumer.done) {
        final numReplies =
          int.parse(new String.fromCharCodes(_lineConsumer.data));
        _replies = new List<RedisReply>(numReplies);
      }
    } else {
      if(_activeConsumer == null) {
        _activeConsumer = _makeRedisConsumer(data[current++]);
      }
      if(current < end) {
        current = _activeConsumer.consume(data, current, end);
        if(_activeConsumer.done) {
          _replies[_repliesReceived++] = _activeConsumer.makeReply();
          _activeConsumer = null;
        }
      }
    }

    if(current < end && !done) {
      current = consume(data, current, end);
    }

    // we've advanced and either are done or ran out
    assert(current > start && (done || current == end));
    return current;
  }

  RedisReply makeReply() => new MultiBulkReply(_replies);

  /// Consumer is done when all replies have been received
  bool get done => _replies != null && _replies.length == _repliesReceived;

  /// Consumer used to get the number of replies in the MultiBulkReply
  _LineConsumer _lineConsumer = new _IntegerConsumer();

  /// Consumer for the current reply being processed
  _RedisConsumer _activeConsumer;

  /// List of resulting replies in this MultiBulkReply
  List<RedisReply> _replies;

  int _repliesReceived = 0;
}

_RedisConsumer _makeRedisConsumer(final int replyType) {
  switch(replyType) {
    case _STATUS: return new _StatusConsumer();
    case _ERROR: return new _ErrorConsumer();
    case _INTEGER: return new _IntegerConsumer();
    case _BULK: return new _BulkConsumer();
    case _MULTI_BULK: return new _MultiBulkConsumer();
    default: throw new InvalidRedisResponseError(
      "The type character was incorrect (${new String.fromCharCode(replyType)}).");
  }
}
