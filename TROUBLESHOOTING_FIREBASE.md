# Firebase Auth Pigeon 디코딩 오류 해결 가이드

오류 메시지 예시:
```
flutter: FirebaseAuthHostApi.signInWithEmailAndPassword ...
flutter: 스택 트레이스: #0      PigeonUserCredential.decode (…)
```
이 오류는 내부 Firebase 패키지(특히 firebase_auth_platform_interface)에서 예상하는 데이터 구조와 실제 전달된 데이터 구조가 일치하지 않을 때 발생합니다.

## 점검 및 해결 방법

1. **Firebase 패키지 버전 업데이트**
   - firebase_auth와 firebase_auth_platform_interface의 최신 버전 혹은 호환 가능한 버전을 사용하고 있는지 확인합니다.
   - pubspec.yaml 파일에서 firebase_auth를 최신 안정 버전(예: ^4.4.x 등)으로 업데이트한 후 `flutter pub upgrade`를 실행하세요.

2. **캐시 정리 및 재빌드**
   - 터미널에서 아래 명령어를 실행하여 캐시를 정리하고 다시 빌드합니다.
     ```
     flutter clean
     flutter pub get
     ```
   - Pigeon 코드가 내부적으로 사용되므로, 별도의 Pigeon 스키마 재생성이 필요하다면 (예: Firebase 관련 변경 시) 재생성하세요:
     ```
     dart run pigeon --input pigeons/schema.dart --dart_out lib/pigeon.dart --objc_header_out ios/Runner/Pigeon.h --objc_source_out ios/Runner/Pigeon.m
     ```

3. **Firebase 설정 파일 확인**
   - GoogleService-Info.plist (iOS)와 google-services.json (Android)가 최신 설정 파일인지 확인하세요.
   - Firebase 콘솔에서 앱 설정이 올바른지 검토합니다.

4. **디버그 로그 확인**
   - Firebase 초기화 및 로그인 처리가 시작될 때 추가 로그를 남겨, Firebase가 정상적으로 초기화되고 있는지 확인하세요.
   - 이미 main.dart에 초기화 로그가 있으므로, 초기화 성공 후 로그인 과정에서 오류가 발생하는지 세부 정보를 분석합니다.

## 결론

내부 Firebase Auth Pigeon 코드에서 문제가 발생하는 것으로 보이므로, 주로 패키지 버전 불일치나 캐시 문제일 가능성이 큽니다. 위의 모든 점검 사항을 적용한 후에도 오류가 지속된다면, Firebase Auth 관련 GitHub 이슈나 커뮤니티 포럼에서 유사 사례를 참고해 보시기 바랍니다.
