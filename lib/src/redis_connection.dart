part of redis_client;



/// The [RedisConnection] wraps the Socket, and provides an API to communicate
/// to redis.
///
/// You instantiate a [RedisConnection] with:
///
///     RedisConnection.connect(connectionString)
///         .then((RedisConnection connection) {
///           // Use your connection
///         });
///
/// where `connectionString` can be any of following:
///
/// - `'pass@host:port/db'`
/// - `'pass@host:port'`
/// - `'pass@host'`
/// - `'host'`
/// - `null` defaults to `'localhost:6379/0'`
abstract class RedisConnection {


  /// Create a new [RedisConnection] with given connectionString.
  static Future<RedisConnection> connect(String connectionString) => _RedisConnection.connect(connectionString);



  /// The connectionString from which the connection settings have been
  /// extruded.
  ///
  /// Once this string has been parsed, it isn't used anymore.
  String connectionString;

  /// Redis connection hostname
  String hostname;

  /// Redis connection password
  String password;

  /// Redis connection port
  int port;

  /// Redis database
  int db;



  /// Closes the connection.
  Future close();


  Map get stats;


  Future select([ int db ]);

  Future<String> sendExpectCode(List<List> cmdWithArgs);

  Future<Object> sendExpectSuccess(List<List> cmdWithArgs);

  Future<int> sendExpectInt(List<List> cmdWithArgs);

  Future<bool> sendExpectIntSuccess(List<List> cmdWithArgs);

  Future<List<int>> sendExpectData(List<List> cmdWithArgs);

  Future<List<List<int>>> sendExpectMultiData(List<List> cmdWithArgs);

  Future<String> sendExpectString(List<List> cmdWithArgs);

  Future<double> sendExpectDouble(List<List> cmdWithArgs);


}


/// The actual implementation of the [RedisConnection].
class _RedisConnection implements RedisConnection {


  // Connection settings

  final String connectionString;

  final String hostname;

  final String password;

  final int port;

  final int db;




  /// The wrapped [Socket].
  Socket _socket;

  SocketWrapper _wrapper;


  /// The completer that resolves the future as soon as the RedisConnection
  /// is connected.
  final Completer<RedisConnection> _connectedCompleter = new Completer<RedisConnection>();

  /// Gets resolved as soon as the connection is up.
  Future<RedisConnection> connected;


  /// The character sequence that ends data.
  ///
  /// `\r\n`
  const List<int> _endData = [ 13, 10 ];


  /// Used to output debug information
  Logger logger = new Logger("redis_client");



  Int8List _cmdBuffer = new Int8List(32 * 1024);

  int _cmdBufferIndex = 0;

  // To Reduce Reallocations
  static final int breathingSpace = 32 * 1024;

  Pipeline pipeline;

  Queue<ExpectRead> _pendingReads = new Queue<ExpectRead>();

  /// Statistics
  int totalBuffersWrites = 0;

  /// Statistics
  int totalBufferFlushes = 0;

  /// Statistics
  int totalBufferResizes = 0;

  /// Statistics
  int totalBytesWritten = 0;

  Map get stats => $(_wrapper.stats).addAll({
    'bufferWrites':totalBuffersWrites,
    'flushes':totalBufferFlushes,
    'bytesWritten': totalBytesWritten,
    'bufferResizes': totalBufferResizes,
  });


  /// Creates a [_RedisConnection], and returns the future for a connection.
  static Future<RedisConnection> connect(String connectionString) {
    var settings = new ConnectionSettings(connectionString);

    var redisConnection = new _RedisConnection(settings.connectionString, settings.hostname, settings.password, settings.port, settings.db);

    return redisConnection.connected.then((_) => redisConnection);
  }


  /// Create a new [RedisConnection] with given connectionString.
  _RedisConnection(this.connectionString, this.hostname, this.password, this.port, this.db) {

    logger.info("Creating socket connection ($hostname, $port)");

    this.connected = Socket.connect(hostname, port)
        .then((Socket socket) {
          logger.info("Connected");

          // Setting up all the listeners so Redis responses can be interpreted.
          socket.listen(_onStreamData, _onStreamError, _onStreamDone);

          if (password != null) return _authenticate();
        })
        .then((_) {
          if (db > 0) return select();
        })
        // The RedisConnection has connected successfully.

        .catchError(_onSocketError);

  }



  /// Selects configured database.
  ///
  /// If db is provided the configuration [db] will be set to it.
  Future select([ int db ]) {
    if (db != null) this.db = db;
    sendExpectSuccess([ "SELECT", db.toString() ]);
  }

  /// Authenticates with configured password.
  Future _authenticate(String _password) => sendExpectSuccess([ "AUTH", password ]);



  /// Gets called when the socket has an error.
  void _onSocketError() {

  }

  /// Handles new data received from stream.
  void _onStreamData(List<int> data) {
    processSocketData("onSocketData");
  }

  /// Handles stream errors
  void _onStreamError(String error) {

  }

  /// Gets called when the stream closes.
  void _onStreamDone() {

  }



  /// Logs the error and creates and returns an Exception.
  Exception createError(err){
    logger.warning(err);
    return new Exception(err);
  }

  int _available() => connected ? _socket.available() : 0;


  processSocketData(callsite){
    int available = _available();
    if (available == 0) return;

    while (true) {
      if (_pendingReads.length == 0) return;

      if (closed)
        throw logError(() => "onSocketData(): Cannot read from closed socket");

      try{
        ExpectRead expectRead = _pendingReads.first; //peek + read next in queue

        if (!expectRead.execute(_wrapper)) {
          return;
        }
      }catch(e){
        logError(() => "ERROR $callsite: parsing read: $e");
      }

      _pendingReads.removeFirst(); //pop if success
    }
  }

  void cmdLog(args){
    var cmd = args.length > 0 ? new String.fromCharCodes(args[0]) : "";
    logger.info ("cmdLog: [$cmd] $args");
  }

  Future sendCommand(List<List> cmdWithArgs){
    Completer task = new Completer();
    ensureConnected().then((_){
      cmdLog(cmdWithArgs);
      writeAllToSendBuffer(cmdWithArgs);
      if (pipeline == null && !flushSendBuffer()) {
        task.completeException(createError("Could not flush socket"));
      }
      task.complete(pipeline == null);
    });

    return task.future;
  }

  bool flushSendBuffer(){
    try {
      if (!connected){
        logger.info("Deferring attempt to flushSendBuffer() since not connected yet");
        return true;
      }
      totalBufferFlushes++;
      logger.info("flushSendBuffer(): ${_available()}");

      int maxAttempts = 100;
      while ((_cmdBufferIndex -= _socket.writeList(_cmdBuffer, 0, _cmdBufferIndex)) > 0 && --maxAttempts > 0);

      resetSendBuffer();
      return maxAttempts > 0;
    }
    catch (e){
      logError(e);
      return false;
    }
  }

  void resetOnError(){
    resetSendBuffer();
  }

  void resetSendBuffer() {
    _cmdBufferIndex = 0;
  }

  List getCmdBytes(String cmdPrefix, int noOfLines){
    String strLines = noOfLines.toString();
    int strLinesLen = strLines.length;

    List bytes = new Int8List(1 + strLinesLen + 2);
    bytes[0] = cmdPrefix.charCodeAt(0);
    List strBytes = strLines.charCodes;
    bytes.setRange(1, strBytes.length, strBytes);
    bytes[1 + strLinesLen] = _Utils.CR;
    bytes[2 + strLinesLen] = _Utils.LF;

    return bytes;
  }

  void writeAllToSendBuffer(List<List> cmdWithArgs){
    writeToSendBuffer(getCmdBytes('*', cmdWithArgs.length));
    for (List safeBinaryValue in cmdWithArgs){
      writeToSendBuffer(getCmdBytes(r'$', safeBinaryValue.length));
      writeToSendBuffer(safeBinaryValue);
      writeToSendBuffer(_endData);
    }
  }

  void writeToSendBuffer(List cmdBytes){
    if ((_cmdBufferIndex + cmdBytes.length) > _cmdBuffer.length) {
      logger.info("resizing sendBuffer $_cmdBufferIndex + ${cmdBytes.length} + $breathingSpace");
      totalBufferResizes++;
      Int8List newLargerBuffer = new Int8List(_cmdBufferIndex + cmdBytes.length + breathingSpace);
      _cmdBuffer.setRange(0, _cmdBuffer.length, newLargerBuffer);
      _cmdBuffer = newLargerBuffer;
    }
    _cmdBuffer.setRange(_cmdBufferIndex, cmdBytes.length, cmdBytes);
    _cmdBufferIndex += cmdBytes.length;

    totalBuffersWrites++;
    totalBytesWritten += cmdBytes.length;
  }

  void queueRead(Completer task, void reader(InputStream stream, Completer task)){
    _pendingReads.add(new ExpectRead(task, reader));
    logger.info("queueRead: #${_pendingReads.length}");
  }

  Future<Object> sendExpectSuccess(List<List> cmdWithArgs){
    Completer task = new Completer();
    sendCommand(cmdWithArgs)
    .then((_){
      if (pipeline != null) {
        pipeline.completeVoidQueuedCommand(_Utils.expectSuccess);
      } else {
        queueRead(task, _Utils.expectSuccess);
      }
    });
    return task.future;
  }

  Future<bool> sendExpectIntSuccess(List<List> cmdWithArgs) =>
    sendExpectInt(cmdWithArgs).transform((success) => success == 1);

  Future<int> sendExpectInt(List<List> cmdWithArgs){
    Completer task = new Completer();
    sendCommand(cmdWithArgs)
    .then((_){
      if (pipeline != null) {
        pipeline.completeIntQueuedCommand(_Utils.readInt);
      } else {
        queueRead(task, _Utils.readInt);
      }
    });
    return task.future;
  }

  Future<List<int>> sendExpectData(List<List> cmdWithArgs){
    Completer task = new Completer();
    sendCommand(cmdWithArgs)
    .then((_){
      if (pipeline != null) {
        pipeline.completeBytesQueuedCommand(_Utils.readData);
      } else {
        queueRead(task, _Utils.readData);
      }
    });
    return task.future;
  }

  Future<List<List<int>>> sendExpectMultiData(List<List> cmdWithArgs){
    Completer task = new Completer();
    sendCommand(cmdWithArgs)
    .then((_){
      if (pipeline != null) {
        pipeline.completeMultiBytesQueuedCommand(_Utils.readMultiData);
      } else {
        queueRead(task, _Utils.readMultiData);
      }
    });
    return task.future;
  }

  Future<String> sendExpectString(List<List> cmdWithArgs) =>
    sendExpectData(cmdWithArgs).transform((List<int> bytes) => new String.fromCharCodes(bytes));

  Future<double> sendExpectDouble(List<List> cmdWithArgs) =>
    sendExpectData(cmdWithArgs).transform((List<int> bytes) => Math.parseDouble(new String.fromCharCodes(bytes)));

  Future<String> sendExpectCode(List<List> cmdWithArgs){
    Completer task = new Completer();
    sendCommand(cmdWithArgs)
    .then((_){
      if (pipeline != null) {
        pipeline.completeStringQueuedCommand(_Utils.expectCode);
      } else {
        queueRead(task, _Utils.expectCode);
      }
    });
    return task.future;
  }

  bool _connected = false;
  bool _closed = false;
  bool get closed => _closed || _wrapper == null;

  close() {
    new Timer(1, (timer) => _close()); //Close on next event-loop
  }

  _close(){
    logger.info("closing..");

    if (_pendingReads.length > 0)
    {
      try {
        logger.info("Trying to close connection with ${_pendingReads.length} pendingReads remaining");
        processSocketData("close");
      } catch(e){
        logError(e);
      }
    }

    connected = false;
    _closed = true;

    if (_socket != null){
      _socket.onData = null;
      _socket.onWrite = null;
      _socket.onError = null;
      _socket.onClosed = null;
      _socket.close();
    }
    _socket = null;
    _wrapper = null;
    if (_onClosed != null) _onClosed();

  }
}




class LogLevel {
  static final int None = 0;
  static final int Error = 1;
  static final int Warn = 2;
  static final int Info = 3;
  static final int Debug = 4;
  static final int All = 5;
}

abstract class Pipeline {
  completeVoidQueuedCommand(Function expectFn);
  completeIntQueuedCommand(Function expectFn);
  completeBytesQueuedCommand(Function expectFn);
  completeMultiBytesQueuedCommand(Function expectFn);
  completeStringQueuedCommand(Function expectFn);
}

class ExpectRead {
  Completer task;
  Function reader;
  List<int> buffer;
  SocketBuffer _socketBuffer;

  ExpectRead(Completer this.task, void this.reader(InputStream stream, Completer task));

  bool execute(SocketWrapper wrapper){
    if (_socketBuffer == null) {
      _socketBuffer = new SocketBuffer(wrapper);
    } else {
      _socketBuffer.rewind();
    }

    reader(_socketBuffer, task);

    return task.future.isComplete;
  }
}


class _Utils {
  static final int CR = 13;
  static final int LF = 10;
  static final int DASH = 45;    // -
  static final int DOLLAR = 36;  // $
  static final int COLON = 58;   // :
  static final int ASTERIX = 42; // *

  static final NoMoreData = null;

  static void logDebug (Function arg) {
    //print(arg());
  }
  static void logError (Function arg) {
    print(arg());
  }

  static Exception createError(arg){
    logError(arg);
    return new Exception(arg);
  }

  static int readByte(InputStream stream){
    List<int> ret = stream.read(1);
    return ret != NoMoreData ? ret[0] : NoMoreData;
  }

  static List<int> readLine(InputStream stream){
    logDebug(() => "readLine: ${stream.available()} total bytes");
    List<int> buffer = new List<int>();
    List<int> ret;
    int c;
    while ((ret = stream.read(1)) != null){
      c = ret[0];
      if (c == CR) continue;
      if (c == LF) break;
      buffer.add(c);
    }
    return buffer;
  }

  static String readString(InputStream stream) => new String.fromCharCodes(readLine(stream));

  static String parseError(String redisError) =>
    redisError == null || redisError.length < 3 || !redisError.startsWith("ERR")
      ? redisError
      : redisError.substring(4);

  static void parseLine(InputStream stream, Completer task, void callback(int charPrefix, String line)){
    logDebug(() => "parseLine: ${stream.available()} total bytes");
    int c = readByte(stream);
    if (c == NoMoreData) return NoMoreData;

    String line = readString(stream);
    logDebug(() => "$c$line");

    if (c == DASH) {
      task.completeException(createError(parseError(line)));
    }

    callback(c, line);
  }

  static void expectSuccess(InputStream stream, Completer task) =>
    parseLine(stream, task, (int c, String line) => task.complete(null));

  static void expectCode(InputStream stream, Completer task) =>
    parseLine(stream, task, (int c, String line) => task.complete(line));

  static Function expectWordFn(String word) {
    return (InputStream stream, Completer task) {
      parseLine(stream, task, (int c, String line) {
        if (line != word) {
          task.completeException(createError("Expected $word got $line"));
        }
        task.complete(null);
      });
    };
  }
  static void expectOk(InputStream stream, Completer task) => expectWordFn("OK")(stream, task);
  static void expectQueued(InputStream stream, Completer task) => expectWordFn("QUEUED")(stream, task);

  static void readInt(InputStream stream, Completer task){
    parseLine(stream, task, (int c, String line) {
      if (c == COLON || c == DOLLAR){
        int ret = null;
        try {
          ret = Math.parseInt(line);
        }catch (e){
          task.completeException(createError("Unknown reply in readInt: $c/$line"));
          return;
        }
        task.complete(ret);
        return;
      }
      task.completeException(createError("Unknown reply on integer response: $c/$line"));
    });
  }

  static void readData(InputStream stream, Completer task){
    List<int> bytes = readLine(stream);
    String line = new String.fromCharCodes(bytes);
    logDebug(() => "readData: $line");
    if (bytes.length == 0) return NoMoreData;

    int c = bytes[0];
    if (c == DOLLAR){
      if (line == r"$-1") {
        task.complete(null);
        return;
      }

      int count;
      try {
        count = Math.parseInt(line.substring(1));
      }catch (e){
        task.completeException(createError("readData: Invalid length: $line: $e"));
        return null;
      }
      if (stream.available() < count) return;

      int offset = 0;
      List<int> buffer = stream.read(count);

      List<int> eol = stream.read(2);
      if (eol.length != 2 || eol[0] != _Utils.CR || eol[1] != _Utils.LF){
        task.completeException(createError("Invalid termination: $eol"));
      }
      else{
        task.complete(buffer);
      }
    }
    else if (c == COLON){
      task.complete(bytes.getRange(1, bytes.length -1));
      return;
    } else {
      task.completeException(createError("Unexpected reply: $line"));
    }
 }

  static void readMultiData(InputStream stream, Completer task){
    parseLine(stream, task, (int c, String line) {
      if (c == ASTERIX){
        int dataCount = null;
        try{
          dataCount = Math.parseInt(line);
        }catch (e){
          task.completeException(createError("readMultiData: Unknown reply on integer response: $c$line: $e"));
          return;
        }
        List<List<int>> ret = new List<List<int>>();
        if (dataCount == -1){
          task.complete(ret);
          return;
        }

        for (int i=0; i<dataCount; i++){
          Completer<List<int>> dataTask = new Completer<List<int>>();
          readData(stream, dataTask);
          if (!dataTask.future.isComplete) {
            task.completeException(createError("readMultiData: Expected synchronus result, aborting..."));
            return;
          }
          if (dataTask.future.exception != null) {
            task.completeException(dataTask.future.exception);
            return;
          }
          ret.add(dataTask.future.value);
        }

        try{
          task.complete(ret);
        }catch(e){
          logError(() => "readMultiData: task.complete(ret): $e");
          throw e;
        }
      } else {
        task.completeException(createError("Unknown reply on integer response: $c$line"));
      }
    });
  }
}

class SocketWrapper {
  Socket socket;
  InputStream inStream;

  Function _closed;
  get closed => _closed();

  Function _available;
  int available() => _available();

  //stats
  int totalRewinds = 0;
  int totalReads = 0;
  int totalReadIntos = 0;
  int totalBytesRead = 0;

  Map get stats => {
    'rewinds': totalRewinds,
    'reads': totalReads,
    'bytesRead': totalBytesRead,
  };

  SocketWrapper(Socket this.socket, this._closed, this._available);

  void pipe(OutputStream output, {bool close: false}) {
    _pipe(socket, output, close:close);
  }

}

//Records what's read so can be replayed if all data hasn't been received.
class SocketBuffer implements Stream {
  List<int> _buffer;
  int _position = 0;
  List<List<int>> _chunks;
  Socket _socket;
  SocketWrapper _wrapper;

  SocketBuffer(SocketWrapper _wrapper)
    : _chunks = new List<List<int>>(),
      this._wrapper = _wrapper,
      _socket = _wrapper.socket;

  int get remaining => _buffer == null ? 0 : _buffer.length - _position;

  /// If a full response cannot be read from the stream, the client gives up,
  /// rewinds the partially read buffer, and re-attempts processing the response
  /// on next onData event
  void rewind(){
    _wrapper.totalRewinds++;

    int bufferSize = $(_chunks.map((x) => x.length)).sum();
    //merge all recorded chunks into a single buffer for easy reading
    _buffer = new Int8List(bufferSize);
    int i = 0;
    for (List<int> chunk in _chunks){
      _buffer.setRange(i, chunk.length, chunk);
      i += chunk.length;
    }
    _chunks = new List<List<int>>();
    _position = 0;
  }

  List<int> readBuffer([int len]){
    if (len == null) len = remaining;
    if (len > remaining) {
      throw new Exception("Can't read $len bytes with only $remaining remaining");
    }

    List<int> buffer = new Int8List(len);
    buffer.setRange(0, len, buffer, _position);
    _position += len;

    return buffer;
  }

  List<int> read([int len]) {
    int bytesToRead = remaining + available();
    if (bytesToRead == 0) return null;
    if (len != null) {
      if (len <= 0) {
        throw new Exception("Illegal length $len, available: $bytesToRead");
      } else if (bytesToRead > len) {
        bytesToRead = len;
      }
    }
//    print("SocketBuffer.read() $len / $bytesToRead ($remaining/${available()})");
    Int8List buffer = new Int8List(bytesToRead);

    //Read from buffer
    int bytesRead = 0;
    int readFromBuffer = Math.min(bytesToRead, remaining);
    if (readFromBuffer > 0){
      buffer.setRange(0, readFromBuffer, _buffer, _position);
      _position += readFromBuffer;
      bytesRead += readFromBuffer;
    }
    bytesToRead -= readFromBuffer;

    //Read from socket
    bytesRead += readInto(buffer, readFromBuffer, bytesToRead);

    _wrapper.totalReads++;
    _wrapper.totalBytesRead += len;

    if (bytesRead == 0) {
      // On MacOS when reading from a tty Ctrl-D reports 1 byte available, 0 bytes read
      return null;
    } else if (bytesRead < buffer.length) {
      //re-size the buffer
      Int8List newBuffer = new Int8List(bytesRead);
      newBuffer.setRange(0, bytesRead, buffer);
      return newBuffer;
    } else {
      return buffer;
    }
  }

  int readInto(List<int> buffer, [int offset = 0, int len]) {
//    print("readInto: ${buffer.length} off: $offset len: $len, closed: $closed");
    if (closed) return null;
    if (len == null) len = buffer.length;
    if (offset < 0) throw new Exception("Illegal offset $offset");
    if (len < 0) throw new Exception("Illegal length $len");

    int bytesRead = _socket.readList(buffer, offset, len);
    List<int> chunk = buffer.getRange(offset, bytesRead);
    _chunks.add(chunk);

    _wrapper.totalReadIntos++;
    _wrapper.totalBytesRead += bytesRead;

    return bytesRead;
  }

  int available() => _wrapper.available();
  void pipe(OutputStream output, {bool close: true}) { _wrapper.pipe(output, close:close); }
  void close() => _socket.close();
  bool get closed => _wrapper.closed;
  void set onData(void callback()) { _socket.onData = callback; }
  void set onClosed(void callback()) { _socket.onClosed = callback; }
  void set onError(void callback(e)) { _socket.onError = callback; }
}

void _pipe(Socket input, OutputStream output, {bool close}) {
  Function pipeDataHandler;
  Function pipeCloseHandler;
  Function pipeNoPendingWriteHandler;

  Function _inputCloseHandler;

  pipeDataHandler = () {
    List<int> data;
    while ((data = input.read()) != null) {
      if (!output.write(data)) {
        input.onData = null;
        output.onNoPendingWrites = pipeNoPendingWriteHandler;
        break;
      }
    }
  };

  pipeCloseHandler = () {
    if (close) output.close();
    if (_inputCloseHandler != null) {
      _inputCloseHandler();
    }
  };

  pipeNoPendingWriteHandler = () {
    input.onData = pipeDataHandler;
    output.onNoPendingWrites = null;
  };

  //_inputCloseHandler = input._clientCloseHandler; //from original _pipe
  input.onData = pipeDataHandler;
  input.onClosed = pipeCloseHandler;
  output.onNoPendingWrites = null;
}
