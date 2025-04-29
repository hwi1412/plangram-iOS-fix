class PigeonUserDetails {
  final String name;
  final String email;

  PigeonUserDetails({
    required this.name,
    required this.email,
  });
}

// 전달받은 데이터가 List<Object?>일 경우 PigeonUserDetails로 변환하는 헬퍼 함수 (업데이트)
PigeonUserDetails? convertToPigeonUserDetails(Object? data) {
  // 실제 데이터 구조 확인을 위한 로그 추가
  print('convertToPigeonUserDetails: received data: $data');

  if (data is List && data.length >= 2) {
    try {
      // 값이 null이 아닌지 체크 후 변환 진행
      final dynamic rawName = data[0];
      final dynamic rawEmail = data[1];

      if (rawName != null && rawEmail != null) {
        final String name = rawName.toString();
        final String email = rawEmail.toString();
        return PigeonUserDetails(name: name, email: email);
      } else {
        print('convertToPigeonUserDetails: null 값 발견 - rawName: $rawName, rawEmail: $rawEmail');
      }
    } catch (e) {
      print('변환 중 오류 발생: $e');
      return null;
    }
  } else {
    print('예상 데이터 형식이 아님: $data');
  }
  return null;
}
