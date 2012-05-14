#library("RedisClient");
#import("dart:io");
#import("Mixin.dart");
#import("SocketBuffer.dart");

interface RedisConnection default _RedisConnection {
  RedisConnection([String connStr]);

  String password;
  String hostName;
  int port;
  int db;
  Map get stats();

  void parse([String connStr]);

  Future select(int selectDb);
  Future<String> sendExpectCode(List<List> cmdWithArgs);
  Future<Object> sendExpectSuccess(List<List> cmdWithArgs);
  Future<int> sendExpectInt(List<List> cmdWithArgs);
  Future<bool> sendExpectIntSuccess(List<List> cmdWithArgs);
  Future<List<int>> sendExpectData(List<List> cmdWithArgs);
  Future<List<List<int>>> sendExpectMultiData(List<List> cmdWithArgs);
  Future<String> sendExpectString(List<List> cmdWithArgs);
  Future<double> sendExpectDouble(List<List> cmdWithArgs);

  void close();
}

interface LogLevel {
  static final int None = 0;
  static final int Error = 1;
  static final int Warn = 2;
  static final int Info = 3;
  static final int Debug = 4;
  static final int All = 5;
}

interface Pipeline {
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

  ExpectRead(Completer this.task, bool this.reader(InputStream stream, Completer task));

  bool execute(SocketWrapper wrapper){
    if (_socketBuffer == null)
      _socketBuffer = new SocketBuffer(wrapper);
    else
      _socketBuffer.rewind();

    reader(_socketBuffer, task);

    return task.future.isComplete;
  }
}

class _RedisConnection implements RedisConnection {
  Socket _socket;
  SocketInputStream _inStream;
  SocketWrapper _wrapper;

  //Valid usages:
  //pass@host:port/db
  //pass@host:port
  //pass@host
  //host
  //null => localhost:6379/0
  String password;
  String hostName = "localhost";
  int port = 6379;
  int db = 0;
  bool connected;
  List endData;
  Queue<List> readChunks;
  int logLevel = LogLevel.None;

  Int8List cmdBuffer;
  int cmdBufferIndex = 0;
  static final int breathingSpace = 32 * 1024; //To Reduce Reallocations
  Pipeline pipeline;

  Queue<ExpectRead> pendingReads;

  //stats
  int totalBuffersWrites = 0;
  int totalBufferFlushes = 0;
  int totalBufferResizes = 0;
  int totalBytesWritten = 0;

  Map get stats() => $(_wrapper.stats).addAll({
    'buffersWrites':totalBuffersWrites,
    'bufferFlushes':totalBufferFlushes,
    'bufferResizes': totalBufferResizes,
    'bytesWritten': totalBytesWritten
  });

  _RedisConnection([String connStr])
    : cmdBuffer = new Int8List(32 * 1024),
      pendingReads = new Queue<ExpectRead>(),
      readChunks = new Queue<List>(),
      endData = "\r\n".charCodes()
  {
    parse(connStr);
  }

  void parse([String connStr]){
    if (connStr == null) return;
    List<String> parts = $(connStr).splitOnLast("@");
    password = parts.length == 2 ? parts[0] : null;
    parts = $(parts.last()).splitOnLast(":");
    bool hasPort = parts.length == 2;
    hostName = parts[0];
    if (hasPort) {
      parts = $(parts.last()).splitOnLast("/");
      port = Math.parseInt(parts[0]);
      db = parts.length == 2 ? Math.parseInt(parts[1]) : 0;
    }
  }

  void logDebug (arg) {
    if (logLevel >= LogLevel.Debug) print(arg);
  }
  void logError (arg) {
    if (logLevel >= LogLevel.Error) print(arg);
  }
  Exception createError(arg){
    logError(arg);
    return new Exception(arg);
  }

  Future<bool> ensureConnected() {
    logDebug("ensureConnected()");
    Completer task = new Completer();
    if (_wrapper != null && !_wrapper.closed) {
      task.complete(false);
      return task.future;
    }

    _socket = new Socket(hostName, port);
    _socket.onConnect = () {
      logDebug("connected!");
      _wrapper.isClosed = false;

      void complete(Object ignore) =>
        db > 0
        ? select(db).then((_) => task.complete(true))
        : task.complete(true);

      if (password != null)
        auth(password).then(complete);
      else
        complete(null);
    };
    _inStream = new SocketInputStream(_socket);
    _wrapper = new SocketWrapper(_socket, _inStream);
    _inStream.onClosed = () => close();
    _inStream.onError = (e) {
      logDebug('connect exception ${e}');
      try { close(); } catch(Exception ex){}
      task.completeException(e);
    };

    _socket.onData = onSocketData;
    return task.future;
  }

  Future select(int _db) => sendExpectSuccess(["SELECT".charCodes(), (db = _db).toString().charCodes()]);

  Future auth(String _password) => sendExpectSuccess(["AUTH".charCodes(), (password = _password).charCodes()]);

  onSocketData() {
    int available = _socket.available();
    logDebug("onSocketData: $available total bytes");
    if (available == 0) return;

    while (true) {
      if (pendingReads.length == 0) return;
      ExpectRead expectRead = pendingReads.first(); //peek + read next in queue
      if (!expectRead.execute(_wrapper)) return;
      pendingReads.removeFirst(); //pop if success
    }
  }

  void cmdLog(args){
    logDebug("cmdLog: $args");
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
    totalBufferFlushes++;
    logDebug("flushSendBuffer(): ${_socket.available()}");

    int maxAttempts = 100;
    while ((cmdBufferIndex -= _socket.writeList(cmdBuffer, 0, cmdBufferIndex)) > 0 && --maxAttempts > 0);

    resetSendBuffer();
    return maxAttempts > 0;
  }

  void resetOnError(){
    resetSendBuffer();
  }

  void resetSendBuffer() {
    cmdBufferIndex = 0;
  }

  List getCmdBytes(String cmdPrefix, int noOfLines){
    String strLines = noOfLines.toString();
    int strLinesLen = strLines.length;

    List bytes = new Int8List(1 + strLinesLen + 2);
    bytes[0] = cmdPrefix.charCodeAt(0);
    List strBytes = strLines.charCodes();
    bytes.setRange(1, strBytes.length, strBytes);
    bytes[1 + strLinesLen] = _Utils.CR;
    bytes[2 + strLinesLen] = _Utils.LF;

    return bytes;
  }

  void writeAllToSendBuffer(List<List> cmdWithArgs){
    writeToSendBuffer(getCmdBytes('*', cmdWithArgs.length));
    for (List safeBinaryValue in cmdWithArgs){
      writeToSendBuffer(getCmdBytes(@'$', safeBinaryValue.length));
      writeToSendBuffer(safeBinaryValue);
      writeToSendBuffer(endData);
    }
  }

  void writeToSendBuffer(List cmdBytes){
    if ((cmdBufferIndex + cmdBytes.length) > cmdBuffer.length) {
      logDebug("resizing sendBuffer $cmdBufferIndex + ${cmdBytes.length} + $breathingSpace");
      Int8List newLargerBuffer = new Int8List(cmdBufferIndex + cmdBytes.length + breathingSpace);
      cmdBuffer.setRange(0, cmdBuffer.length, newLargerBuffer);
      cmdBuffer = newLargerBuffer;
    }
    cmdBuffer.setRange(cmdBufferIndex, cmdBytes.length, cmdBytes);
    cmdBufferIndex += cmdBytes.length;

    totalBuffersWrites++;
    totalBytesWritten += cmdBytes.length;
  }

  void queueRead(Completer task, void reader(InputStream stream, Completer task)){
    pendingReads.add(new ExpectRead(task, reader));
    logDebug("queueRead: #${pendingReads.length}");
  }

  Future<Object> sendExpectSuccess(List<List> cmdWithArgs){
    Completer task = new Completer();
    sendCommand(cmdWithArgs)
    .then((_){
      if (pipeline != null)
        pipeline.completeVoidQueuedCommand(_Utils.expectSuccess);
      else
        queueRead(task, _Utils.expectSuccess);
    });
    return task.future;
  }

  Future<bool> sendExpectIntSuccess(List<List> cmdWithArgs) =>
    sendExpectInt(cmdWithArgs).transform((success) => success == 1);

  Future<int> sendExpectInt(List<List> cmdWithArgs){
    Completer task = new Completer();
    sendCommand(cmdWithArgs)
    .then((_){
      if (pipeline != null)
        pipeline.completeIntQueuedCommand(_Utils.readInt);
      else
        queueRead(task, _Utils.readInt);
    });
    return task.future;
  }

  Future<List<int>> sendExpectData(List<List> cmdWithArgs){
    Completer task = new Completer();
    sendCommand(cmdWithArgs)
    .then((_){
      if (pipeline != null)
        pipeline.completeBytesQueuedCommand(_Utils.readData);
      else
        queueRead(task, _Utils.readData);
    });
    return task.future;
  }

  Future<List<List<int>>> sendExpectMultiData(List<List> cmdWithArgs){
    Completer task = new Completer();
    sendCommand(cmdWithArgs)
    .then((_){
      if (pipeline != null)
        pipeline.completeMultiBytesQueuedCommand(_Utils.readMultiData);
      else
        queueRead(task, _Utils.readMultiData);
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
      if (pipeline != null)
        pipeline.completeStringQueuedCommand(_Utils.expectCode);
      else
        queueRead(task, _Utils.expectCode);
    });
    return task.future;
  }

  bool get closed() => _inStream == null || _inStream.closed;



  close() {
    logDebug("closing..");
    if (_wrapper != null) _wrapper.isClosed = true;
    if (_inStream != null) _inStream.close();
    if (_socket != null){
      _socket.onData = null;
      _socket.onWrite = null;
      _socket.onError = null;
      _socket.close();
    }
    _inStream = null;
    _socket = null;
    _wrapper = null;
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

  static void logDebug(arg){
    //print("$arg");
  }
  static void logError(arg){
    //print("$arg");
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
    logDebug("readLine: ${stream.available()} total bytes");
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
    logDebug("parseLine: ${stream.available()} total bytes");
    int c = readByte(stream);
    if (c == NoMoreData) return NoMoreData;

    String line = readString(stream);
    logDebug("$c$line");

    if (c == DASH)
      task.completeException(createError(parseError(line)));

    callback(c, line);
  }

  static void expectSuccess(InputStream stream, Completer task) =>
    parseLine(stream, task, (int c, String line) => task.complete(null));

  static void expectCode(InputStream stream, Completer task) =>
    parseLine(stream, task, (int c, String line) => task.complete(line));

  static Function expectWordFn(String word) {
    return (InputStream stream, Completer task) {
      parseLine(stream, task, (int c, String line) {
        if (line != word)
          task.completeException(createError("Expected $word got $line"));
        task.complete(null);
      });
    };
  }
  static void expectOk(InputStream stream, Completer task) => expectWordFn("OK")(stream, task);
  static void expectQueued(InputStream stream, Completer task) => expectWordFn("QUEUED")(stream, task);

  static void readInt(InputStream stream, Completer task){
    parseLine(stream, task, (int c, String line) {
      try {
        if (c == COLON || c == DOLLAR){
          task.complete(Math.parseInt(line));
          return;
        }
      }catch (var e){ logError("readInt: $e"); }
      task.completeException(createError("Unknown reply on integer response: $c/$line"));
    });
  }

  static void readData(InputStream stream, Completer task){
    List<int> bytes = readLine(stream);
    String line = new String.fromCharCodes(bytes);
    logDebug("readData: $line");
    if (bytes.length == 0) return NoMoreData;

    int c = bytes[0];
    if (c == DOLLAR){
      if (line == @"$-1") {
        task.complete(null);
        return;
      }

      try {
        int count = Math.parseInt(line.substring(1));
        if (stream.available() < count) return;

        int offset = 0;
        List<int> buffer = stream.read(count);

        List<int> eol = stream.read(2);
        if (eol.length != 2 || eol[0] != _Utils.CR || eol[1] != _Utils.LF)
          task.completeException(createError("Invalid termination: $eol"));
        else
          task.complete(buffer);

        return;
      }catch (var e){ logError("readData: $e"); }
      task.completeException(createError("Invalid length: $line"));
      return;
    }
    if (c == COLON){
      task.complete(bytes.getRange(1, bytes.length -1));
      return;
    }
    task.completeException(createError("Unexpected reply: $line"));
 }

  static void readMultiData(InputStream stream, Completer task){
    parseLine(stream, task, (int c, String line) {
      try{
        if (c == ASTERIX){
          int dataCount = Math.parseInt(line);
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

          task.complete(ret);
          return;
        }
      }catch (var e){ logError("readMultiData: $e"); }
      task.completeException(createError("Unknown reply on integer response: $c$line"));
    });
  }

}