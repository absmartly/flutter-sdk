import 'dart:core';
import 'dart:typed_data';

import '../../helper/funtions.dart';
import '../buffers.dart';

abstract class MD5 {

  static Uint8List digestBase64UrlNoPadding(Uint8List key,
      {int? offset, int? len,}) {
    if(offset == null || len == null){
      return digestBase64UrlNoPadding(key, offset: 0, len: key.length);
    }else{


      final List<int> state = md5state(key, offset, len);

      final int a = state[0];
      final int b = state[1];
      final int c = state[2];
      final int d = state[3];

      final Uint8List result = Uint8List.fromList(List.generate(22, (index) => 0  ));;

      int t = a;
      result[0] = Base64URLNoPaddingChars[(t >>> 2) & 63];
      result[1] = Base64URLNoPaddingChars[((t & 3) << 4) | (((t >>> 12)) & 15)];
      result[2] = Base64URLNoPaddingChars[(((t >>> 8) & 15) << 2) | ((t >>> 22) & 3)];
      result[3] = Base64URLNoPaddingChars[(t >>> 16) & 63];

      t = (a >>> 24) | (b << 8);
      result[4] = Base64URLNoPaddingChars[(t >>> 2) & 63];
      result[5] = Base64URLNoPaddingChars[((t & 3) << 4) | (((t >>> 12)) & 15)];
      result[6] = Base64URLNoPaddingChars[(((t >>> 8) & 15) << 2) | ((t >>> 22) & 3)];
      result[7] = Base64URLNoPaddingChars[(t >>> 16) & 63];

      t = (b >>> 16) | (c << 16);
      result[8] = Base64URLNoPaddingChars[(t >>> 2) & 63];
      result[9] = Base64URLNoPaddingChars[((t & 3) << 4) | (((t >>> 12)) & 15)];
      result[10] = Base64URLNoPaddingChars[(((t >>> 8) & 15) << 2) | ((t >>> 22) & 3)];
      result[11] = Base64URLNoPaddingChars[(t >>> 16) & 63];

      t = c >>> 8;
      result[12] = Base64URLNoPaddingChars[(t >>> 2) & 63];
      result[13] = Base64URLNoPaddingChars[((t & 3) << 4) | (((t >>> 12)) & 15)];
      result[14] = Base64URLNoPaddingChars[(((t >>> 8) & 15) << 2) | ((t >>> 22) & 3)];
      result[15] = Base64URLNoPaddingChars[(t >>> 16) & 63];

      t = d;
      result[16] = Base64URLNoPaddingChars[(t >>> 2) & 63];
      result[17] = Base64URLNoPaddingChars[((t & 3) << 4) | (((t >>> 12)) & 15)];
      result[18] = Base64URLNoPaddingChars[(((t >>> 8) & 15) << 2) | ((t >>> 22) & 3)];
      result[19] = Base64URLNoPaddingChars[(t >>> 16) & 63];

      t = d >>> 24;
      result[20] = Base64URLNoPaddingChars[(t >>> 2) & 63];
      result[21] = Base64URLNoPaddingChars[(t & 3) << 4];

      return result;

    }
  }


  static int cmn(int q, int a, int b, int x, int s, int t) {
    a = a + q + x + t;
    return leftRotate(a, s) + b;
  }

  static int ff(int a, int b, int c, int d, int x, int s, int t) {
    return cmn((b & c) | (~b & d), a, b, x, s, t);
  }

  static int gg(int a, int b, int c, int d, int x, int s, int t) {
    return cmn((b & d) | (c & ~d), a, b, x, s, t);
  }

  static int hh(int a, int b, int c, int d, int x, int s, int t) {
    return cmn(b ^ c ^ d, a, b, x, s, t);
  }

  static int ii(int a, int b, int c, int d, int x, int s, int t) {
    return cmn(c ^ (b | ~d), a, b, x, s, t);
  }

  static void md5cycle(List<int?> x, List<int?> k) {
  int a = x[0]!;
  int b = x[1]!;
  int c = x[2]!;
  int d = x[3]!;

  a = ff(a, b, c, d, k[0]!, 7, -680876936);
  d = ff(d, a, b, c, k[1]!, 12, -389564586);
  c = ff(c, d, a, b, k[2]!, 17, 606105819);
  b = ff(b, c, d, a, k[3]!, 22, -1044525330);
  a = ff(a, b, c, d, k[4]!, 7, -176418897);
  d = ff(d, a, b, c, k[5]!, 12, 1200080426);
  c = ff(c, d, a, b, k[6]!, 17, -1473231341);
  b = ff(b, c, d, a, k[7]!, 22, -45705983);
  a = ff(a, b, c, d, k[8]!, 7, 1770035416);
  d = ff(d, a, b, c, k[9]!, 12, -1958414417);
  c = ff(c, d, a, b, k[10]!, 17, -42063);
  b = ff(b, c, d, a, k[11]!, 22, -1990404162);
  a = ff(a, b, c, d, k[12]!, 7, 1804603682);
  d = ff(d, a, b, c, k[13]!, 12, -40341101);
  c = ff(c, d, a, b, k[14]!, 17, -1502002290);
  b = ff(b, c, d, a, k[15]!, 22, 1236535329);

  a = gg(a, b, c, d, k[1]!, 5, -165796510);
  d = gg(d, a, b, c, k[6]!, 9, -1069501632);
  c = gg(c, d, a, b, k[11]!, 14, 643717713);
  b = gg(b, c, d, a, k[0]!, 20, -373897302);
  a = gg(a, b, c, d, k[5]!, 5, -701558691);
  d = gg(d, a, b, c, k[10]!, 9, 38016083);
  c = gg(c, d, a, b, k[15]!, 14, -660478335);
  b = gg(b, c, d, a, k[4]!, 20, -405537848);
  a = gg(a, b, c, d, k[9]!, 5, 568446438);
  d = gg(d, a, b, c, k[14]!, 9, -1019803690);
  c = gg(c, d, a, b, k[3]!, 14, -187363961);
  b = gg(b, c, d, a, k[8]!, 20, 1163531501);
  a = gg(a, b, c, d, k[13]!, 5, -1444681467);
  d = gg(d, a, b, c, k[2]!, 9, -51403784);
  c = gg(c, d, a, b, k[7]!, 14, 1735328473);
  b = gg(b, c, d, a, k[12]!, 20, -1926607734);

  a = hh(a, b, c, d, k[5]!, 4, -378558);
  d = hh(d, a, b, c, k[8]!, 11, -2022574463);
  c = hh(c, d, a, b, k[11]!, 16, 1839030562);
  b = hh(b, c, d, a, k[14]!, 23, -35309556);
  a = hh(a, b, c, d, k[1]!, 4, -1530992060);
  d = hh(d, a, b, c, k[4]!, 11, 1272893353);
  c = hh(c, d, a, b, k[7]!, 16, -155497632);
  b = hh(b, c, d, a, k[10]!, 23, -1094730640);
  a = hh(a, b, c, d, k[13]!, 4, 681279174);
  d = hh(d, a, b, c, k[0]!, 11, -358537222);
  c = hh(c, d, a, b, k[3]!, 16, -722521979);
  b = hh(b, c, d, a, k[6]!, 23, 76029189);
  a = hh(a, b, c, d, k[9]!, 4, -640364487);
  d = hh(d, a, b, c, k[12]!, 11, -421815835);
  c = hh(c, d, a, b, k[15]!, 16, 530742520);
  b = hh(b, c, d, a, k[2]!, 23, -995338651);

  a = ii(a, b, c, d, k[0]!, 6, -198630844);
  d = ii(d, a, b, c, k[7]!, 10, 1126891415);
  c = ii(c, d, a, b, k[14]!, 15, -1416354905);
  b = ii(b, c, d, a, k[5]!, 21, -57434055);
  a = ii(a, b, c, d, k[12]!, 6, 1700485571);
  d = ii(d, a, b, c, k[3]!, 10, -1894986606);
  c = ii(c, d, a, b, k[10]!, 15, -1051523);
  b = ii(b, c, d, a, k[1]!, 21, -2054922799);
  a = ii(a, b, c, d, k[8]!, 6, 1873313359);
  d = ii(d, a, b, c, k[15]!, 10, -30611744);
  c = ii(c, d, a, b, k[6]!, 15, -1560198380);
  b = ii(b, c, d, a, k[13]!, 21, 1309151649);
  a = ii(a, b, c, d, k[4]!, 6, -145523070);
  d = ii(d, a, b, c, k[11]!, 10, -1120210379);
  c = ii(c, d, a, b, k[2]!, 15, 718787259);
  b = ii(b, c, d, a, k[9]!, 21, -343485551);

  x[0] = x[0]! + a;
  x[1] = x[1]! + b;
  x[2] = x[2]! + c;
  x[3] = x[3]! + d;
  }


  static final BufferState threadState = BufferState();


  //  static final ThreadLocal<BufferState> threadState = new ThreadLocal<BufferState>() {
  // @Override
  // public BufferState initialValue() {
  // return new BufferState();
  // }
  // };

   static List<int> md5state(Uint8List key, int offset, int len) {
  final int n = offset + (len & ~63);
  final BufferState bufferState = threadState;//.get();
  final List<int?> block = bufferState.block;
  final List<int?> state = bufferState.state;

  state[0] = 1732584193;
  state[1] = -271733879;
  state[2] = -1732584194;
  state[3] = 271733878;

  int i = offset;
  for (; i < n; i += 64) {
  for (int w = 0; w < 16; ++w) {
  block[w] = Buffers.getUInt32(key, i + (w << 2));
  }

  md5cycle(state, block);
  }

  final int m = len & ~3;
  int w = 0;
  for (; i < m; i += 4) {
  block[w++] = Buffers.getUInt32(key, i);
  }

  switch (len & 3) {
  case 3:
  block[w++] = Buffers.getUInt24(key, i) | 0x80000000;
  break;
  case 2:
  block[w++] = Buffers.getUInt16(key, i) | 0x800000;
  break;
  case 1:
  block[w++] = Buffers.getUInt8(key, i) | 0x8000;
  break;
  default:
  block[w++] = 0x80;
  break;
  }

  if (w > 14) {
  if (w < 16) {
  block[w] = 0;
  }

  md5cycle(state, block);
  w = 0;
  }

  for (; w < 16; ++w) {
  block[w] = 0;
  }

  block[14] = len << 3;
  md5cycle(state, block);
  return List.generate(state.length, (index) => state[index]!);
  }

  static final Uint8List Base64URLNoPaddingChars = Uint8List.fromList([stringToByte('A'), stringToByte('B'), stringToByte('C'), stringToByte('D'), stringToByte('E'), stringToByte('F'), stringToByte('G'), stringToByte('H'), stringToByte('I'), stringToByte('J'), stringToByte('K'), stringToByte('L'),
  stringToByte('M'), stringToByte('N'), stringToByte('O'), stringToByte('P'), stringToByte('Q'), stringToByte('R'), stringToByte('S'), stringToByte('T'), stringToByte('U'), stringToByte('V'), stringToByte('W'), stringToByte('X'), stringToByte('Y'), stringToByte('Z'), stringToByte('a'), stringToByte('b'), stringToByte('c'), stringToByte('d'), stringToByte('e'), stringToByte('f'), stringToByte('g'),
  stringToByte('h'), stringToByte('i'), stringToByte('j'), stringToByte('k'), stringToByte('l'), stringToByte('m'), stringToByte('n'), stringToByte('o'), stringToByte('p'), stringToByte('q'), stringToByte('r'), stringToByte('s'), stringToByte('t'), stringToByte('u'), stringToByte('v'), stringToByte('w'), stringToByte('x'), stringToByte('y'), stringToByte('z'), stringToByte('0'), stringToByte('1'),
  stringToByte('2'), stringToByte('3'), stringToByte('4'), stringToByte('5'), stringToByte('6'), stringToByte('7'), stringToByte('8'), stringToByte('9'), stringToByte('-'), stringToByte('_'),
  ]);

  static int stringToByte(String char){
  return char.codeUnitAt(0);
  }




}

class BufferState {
  List<int?> block = List.filled(16, null, growable: false);
  List<int?> state = List.filled(4, null, growable: false);
}
