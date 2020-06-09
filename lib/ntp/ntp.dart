part of ntp;

class NTP {
  /// Return NTP delay in milliseconds
  static Future<int> getNtpOffset({String lookUpAddress = '0.fr.pool.ntp.org', int port = 123, DateTime localTime}) async {
    final DateTime time = localTime ?? DateTime.now();
    final _NTPMessage _ntpMessage = _NTPMessage();

    final List<InternetAddress> addressArray = await InternetAddress.lookup(lookUpAddress);
    final List<int> buffer = _ntpMessage.toByteArray();

    _ntpMessage.encodeTimestamp(buffer, 40, (time.millisecondsSinceEpoch / 1000.0) + _ntpMessage.timeToUtc);
    // Init datagram socket to anyIPv4 and to port 0
    final RawDatagramSocket _datagramSocket =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: true);
    // Send buffer packet to the address from [addressArray] and port [port]
    _datagramSocket.send(buffer, addressArray.first, port);
    // Receive packet from socket
    Datagram packet;

    try {
      await _datagramSocket.firstWhere((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          packet = _datagramSocket.receive();
        }

        return packet != null;
      });
    } catch (e) {
      rethrow;
    } finally {
      _datagramSocket.close();
    }

    if (packet == null) return Future<int>.error('Error: Packet is empty!');

    final int offset = _parseData(packet.data, time);
    return offset;
  }

  /// Get current NTP time
  static Future<DateTime> now() async {
    final DateTime localTime = DateTime.now();
    final int offset = await getNtpOffset(localTime: localTime);
    return DateTime.now().add(Duration(milliseconds: offset));
  }

  /// Parse data from datagram socket.
  static int _parseData(List<int> data, DateTime time) {
    final _NTPMessage _ntpMessage = _NTPMessage(data);
    final double destinationTimestamp = (time.millisecondsSinceEpoch / 1000.0) + 2208988800.0;
    final double localClockOffset = ((_ntpMessage._receiveTimestamp - _ntpMessage._originateTimestamp) +
            (_ntpMessage._transmitTimestamp - destinationTimestamp)) /
        2;

    return (localClockOffset * 1000).toInt();
  }
}
