import 'package:flutter/services.dart';

/// ===============================
/// 채널/상수
/// ===============================
const kAndroidOverlayChannel = MethodChannel(
  'native_overlay_channel',
); // Android 권한/오버레이
const kIosDirectoryChannel = MethodChannel(
  'call_directory_channel',
); // iOS 콜 디렉터리
const kAndroidLookupChannelName = 'incoming_lookup'; // Android headless 조회 채널

const labelsBoxName = 'labels'; // 번호→라벨 저장 Hive 박스명
