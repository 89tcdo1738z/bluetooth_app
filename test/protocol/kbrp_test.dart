import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kjr_monitor/protocol/kbrp.dart';

void main() {
  group('KBRP CRC16', () {
    test('通过 CCITT-FALSE 标准校验向量', () {
      expect(KbrpCodec.crc16('123456789'.codeUnits), 0x29b1);
    });
  });

  group('KBRP 分片重组', () {
    test('按协议第 15 章重组 Device Status', () {
      final assembler = KbrpAssembler();
      final first = Uint8List.fromList([
        0x01,
        0x02,
        0x01,
        0x00,
        0x00,
        0x02,
        0x16,
        0x00,
        0x01,
        0x03,
        0x01,
        0x1d,
        0x40,
        0xe2,
        0x01,
        0x00,
        0x00,
        0xf1,
        0x53,
        0x65,
      ]);
      final second = Uint8List.fromList([
        0x01,
        0x02,
        0x01,
        0x00,
        0x01,
        0x02,
        0x16,
        0x00,
        0x10,
        0x0e,
        0x00,
        0x00,
        0x64,
        0x00,
        0xff,
        0xff,
        0xea,
        0xe8,
      ]);

      expect(assembler.add(first), isNull);
      final message = assembler.add(second);

      expect(message, isA<DeviceStatus>());
      final status = message! as DeviceStatus;
      expect(status.runState, RunState.therapy);
      expect(status.ventilationMode, VentilationMode.cpap);
      expect(status.uptimeMs, 123456);
      expect(status.therapyElapsedS, 3600);
      expect(status.pressureSetting1X10, 100);
      expect(status.pressureSetting2X10, isNull);
    });

    test('支持乱序和重复分片', () {
      final frames = _frames(
        KbrpMessageType.deviceStatus,
        12,
        Uint8List.fromList([
          1,
          1,
          2,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          40,
          0,
          120,
          0,
        ]),
        fragmentSize: 8,
      );
      final assembler = KbrpAssembler();

      expect(assembler.add(frames[1]), isNull);
      expect(assembler.add(frames[1]), isNull);
      expect(assembler.add(frames[0]), isNull);
      final message = assembler.add(frames[2]);

      expect(message, isA<DeviceStatus>());
      expect((message! as DeviceStatus).pressureSetting2X10, 120);
    });

    test('CRC 错误时拒绝整条消息', () {
      final frames = _frames(
        KbrpMessageType.deviceStatus,
        2,
        Uint8List(20)..[0] = 1,
        fragmentSize: 64,
      );
      frames.single[8] ^= 0x01;

      expect(
        () => KbrpAssembler().add(frames.single),
        throwsA(isA<KbrpProtocolException>()),
      );
    });
  });

  group('KBRP Payload', () {
    test('Metrics 按 Valid Mask 解码并保留有符号流量', () {
      final payload = Uint8List(28);
      final data = ByteData.sublistView(payload);
      data.setUint8(0, 1);
      data.setUint16(2, 0x0003, Endian.little);
      data.setUint32(4, 1000, Endian.little);
      data.setUint16(8, 103, Endian.little);
      data.setInt16(10, -125, Endian.little);
      data.setUint16(12, 999, Endian.little);

      final message = _decodeSingle(
        KbrpMessageType.realtimeMetrics,
        8,
        payload,
      ) as RealtimeMetrics;

      expect(message.pressureX10, 103);
      expect(message.flowX10, -125);
      expect(message.leakageX10, isNull);
    });

    test('Report ID 以 16 位十六进制字符串保留 uint64', () {
      final payload = Uint8List(68);
      final data = ByteData.sublistView(payload);
      data.setUint8(0, 1);
      data.setUint8(1, 1);
      for (var index = 0; index < 8; index++) {
        payload[8 + index] = index + 1;
      }

      final report = _decodeSingle(
        KbrpMessageType.latestReport,
        1,
        payload,
      ) as LatestReport;

      expect(report.reportId, '0807060504030201');
      expect(report.hasReport, isTrue);
    });
  });
}

KbrpMessage _decodeSingle(
  KbrpMessageType type,
  int sequence,
  Uint8List payload,
) {
  return KbrpAssembler().add(
    _frames(type, sequence, payload, fragmentSize: 512).single,
  )!;
}

List<Uint8List> _frames(
  KbrpMessageType type,
  int sequence,
  Uint8List payload, {
  required int fragmentSize,
}) {
  final crc = KbrpCodec.crc16([
    1,
    type.value,
    sequence & 0xff,
    sequence >> 8,
    ...payload,
  ]);
  final body = Uint8List(payload.length + 2)
    ..setRange(0, payload.length, payload);
  ByteData.sublistView(body).setUint16(payload.length, crc, Endian.little);
  final count = (body.length / fragmentSize).ceil();
  return [
    for (var index = 0; index < count; index++)
      _frame(
        type,
        sequence,
        index,
        count,
        body,
        index * fragmentSize,
        mathMin((index + 1) * fragmentSize, body.length),
      ),
  ];
}

Uint8List _frame(
  KbrpMessageType type,
  int sequence,
  int index,
  int count,
  Uint8List body,
  int start,
  int end,
) {
  final value = Uint8List(8 + end - start);
  final data = ByteData.sublistView(value);
  data.setUint8(0, 1);
  data.setUint8(1, type.value);
  data.setUint16(2, sequence, Endian.little);
  data.setUint8(4, index);
  data.setUint8(5, count);
  data.setUint16(6, body.length, Endian.little);
  value.setRange(8, value.length, body.sublist(start, end));
  return value;
}

int mathMin(int a, int b) => a < b ? a : b;
