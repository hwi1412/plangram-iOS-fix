import 'package:plangram/util/pigeon_converter.dart';

void processUserData(Object? data) {
  // 직접 캐스팅 대신 헬퍼 함수를 사용
  final details = convertToPigeonUserDetails(data);

  if (details == null) {
    print('데이터 변환 실패');
    // 오류 처리 로직 추가
    return;
  }

  print('User Name: ${details.name}, Email: ${details.email}');
}

mixin data {}
