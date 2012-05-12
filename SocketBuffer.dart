#library("RedisClient");
#import("dart:io");
#import("Mixin.dart");

class SocketWrapper {
  Socket socket;
  SocketInputStream inStream;
  bool isClosed; 
  
  //stats
  int totalRewinds = 0;
  int totalReads = 0;
  int totalReadIntos = 0;
  int totalBytesRead = 0;
  
  Map get stats() => {
    'rewinds': totalRewinds,
    'reads': totalReads,
    'readIntos': totalReadIntos,
    'bytesRead': totalBytesRead
  };
  
  SocketWrapper(Socket this.socket, SocketInputStream this.inStream);
  
  //The Stream takes over the close event + manages the socket close lifecycle
  bool get closed() => isClosed != null ? isClosed : inStream.closed;

  void pipe(OutputStream output, [bool close]) { inStream.pipe(output, close); }
}

//Records what's read so can be replayed if all data hasn't been received.
class SocketBuffer implements InputStream {
  List<int> _buffer;
  int _position = 0;
  List<List<int>> _chunks;
  Socket _socket;
  SocketWrapper _wrapper;
  
  SocketBuffer(SocketWrapper _wrapper) 
    : _chunks = new List<List<int>>(),
      this._wrapper = _wrapper,
      _socket = _wrapper.socket;
    
  int get remaining() => _buffer == null ? 0 : _buffer.length - _position; 
  
  //if a full response cannot be read from the stream, the client gives up, 
  //rewinds the partially read buffer, and re-attempts processing the response on next onData event    
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
    if (len > remaining) 
      throw new Exception("Can't read $len bytes with only $remaining remaining");
    
    List<int> buffer = new Int8List(len);
    buffer.setRange(0, len, buffer, _position);
    _position += len;
    
    return buffer;
  }
  
  List<int> read([int len]) {
    int bytesToRead = remaining + available();
    if (bytesToRead == 0) return null;
    if (len !== null) {
      if (len <= 0) 
        throw new Exception("Illegal length $len, available: $bytesToRead");
      else if (bytesToRead > len) 
        bytesToRead = len;      
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
    if (len === null) len = buffer.length;
    if (offset < 0) throw new Exception("Illegal offset $offset");
    if (len < 0) throw new Exception("Illegal length $len");
    
    int bytesRead = _socket.readList(buffer, offset, len);
    List<int> chunk = buffer.getRange(offset, bytesRead);    
    _chunks.add(chunk);
    
    _wrapper.totalReadIntos++;
    _wrapper.totalBytesRead += bytesRead;
    
    return bytesRead;
  }
  
  int available() => _socket.available();
  void pipe(OutputStream output, [bool close]) { _wrapper.pipe(output, close); }
  void close() => _socket.close();
  bool get closed() => _wrapper.closed;
  void set onData(void callback()) { _socket.onData = callback; }
  void set onClosed(void callback()) { _socket.onClosed = callback; }
  void set onError(void callback(e)) { _socket.onError = callback; }
}
