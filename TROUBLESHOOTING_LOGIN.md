# 로그인 및 데이터 변환 오류 해결 가이드

1. 직접 캐스팅 코드 점검
   - 프로젝트 전체에서 "as PigeonUserDetails" 같은 직접 캐스팅 구문이 남아 있는지 검색하세요.
   - 만약 있다면 convertToPigeonUserDetails 헬퍼 함수를 사용하도록 코드를 수정하세요.
     예)
       // 기존 코드:
       // final details = data as PigeonUserDetails?;
       
       // 변경된 코드:
       final details = convertToPigeonUserDetails(data);
       if (details == null) {
         // 오류 처리
         return;
       }

2. Pigeon 코드 재생성
   - 터미널에서 캐시를 정리하고, 최신 Pigeon 스키마에 맞게 코드를 재생성합니다.
     ```
     flutter clean
     flutter pub get
     dart run pigeon --input pigeons/schema.dart --dart_out lib/pigeon.dart --objc_header_out ios/Runner/Pigeon.h --objc_source_out ios/Runner/Pigeon.m
     ```
   - 자동 생성된 Pigeon 코드와 스키마 파일(pigeons/schema.dart)을 다시 한 번 확인하세요.

3. 변환 함수 로그 확인 및 수정
   - /lib/util/pigeon_converter.dart의 convertToPigeonUserDetails 함수에 추가한 로그로 실제 전달되는 데이터 구조를 확인합니다.
   - 예상하는 데이터 구조([이름, 이메일] 등)와 다르다면, 함수 로직을 실제 구조에 맞게 수정하세요.
     예)
       ```dart
       print('convertToPigeonUserDetails: received data: $data');
       ```
       
4. 로그인 관련 에러 로깅 강화
   - 로그인 프로세스가 진행되는 /lib/providers/login_provider.dart와 /lib/screen/login_screen.dart 파일에 더 자세한 로그(스택 트레이스 포함)를 남겨 실제 오류 원인을 파악하세요.
   - 예를 들어, catch 블록에 아래와 같이 로그 출력하는 코드를 추가합니다:
       ```dart
       } catch (e, stack) {
         print("Unknown error: $e");
         print("Stack trace: $stack");
         _errorMessage = '알 수 없는 오류가 발생했습니다. 다시 시도해주세요.';
         notifyListeners();
       }
       ```

5. 불필요한 Pigeon 관련 코드를 사용하지 않는 경우
   - 로그인 과정에 Pigeon 데이터 변환 기능이 실제로 필요 없다면, 해당 호출이나 관련 코드가 호출되지 않도록 제거 또는 조건부 실행 처리하세요.

위 모든 사항을 점검한 후에도 문제가 지속된다면,
- Firebase 콘솔에서 로그인 시도 시 발생하는 오류 코드 및 메시지를 확인하고,
- 관련된 다른 코드(예: 성공 화면에서 사용되는 일부 Pigeon 관련 로직)가 로그인 플로우에 영향을 미치고 있는지 면밀히 검토해 보시기 바랍니다.
