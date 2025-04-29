# Pigeon 데이터 변환 문제 해결 가이드

1. 직접 캐스팅 제거 및 헬퍼 함수 사용
   - 프로젝트 내에서 "as PigeonUserDetails"를 검색하여 모두 제거하세요.
   - 대신 변환이 필요한 부분은 아래와 같이 교체합니다:
     ```
     // 기존 코드:
     // final details = data as PigeonUserDetails?;
     
     // 변경된 코드:
     final details = convertToPigeonUserDetails(data);
     if (details == null) {
       // 오류 처리
     }
     ```
2. Pigeon 코드 재생성
   - 터미널에서 다음 명령어를 실행하세요:
     ```
     flutter clean
     flutter pub get
     dart run pigeon --input pigeons/schema.dart --dart_out lib/pigeon.dart --objc_header_out ios/Runner/Pigeon.h --objc_source_out ios/Runner/Pigeon.m
     ```
3. 데이터 구조 확인 및 변환 함수 수정
   - convertToPigeonUserDetails 함수에서 로그로 출력되는 데이터를 확인하세요:
     ```
     print('convertToPigeonUserDetails: received data: $data');
     ```
   - 실제 데이터 구조가 [이름, 이메일]과 같은 예상 구조와 다르면, 함수 로직을 수정하여 올바른 변환을 수행하세요.
