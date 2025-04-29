# plangram

this will be absoulty success application

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## CocoaPods 문제 해결

[중요] pod install 명령어는 프로젝트 루트가 아닌 ios 디렉토리에서 실행해야 합니다.

터미널에서 ios 디렉토리로 이동:
   cd ios

이후 아래 단계를 진행하세요:

1. CocoaPods specs 저장소 업데이트:
   pod repo update
2. pod 설치:
   pod install

[참고] 만약 아래와 같은 메시지가 나타난다면 Xcode의 Runner 타겟 Base Configuration이 올바르게 설정되어 있는지 확인하세요.
"CocoaPods did not set the base configuration of your project..."
- Xcode에서 Runner 타겟의 Build Settings로 이동
- Base Configuration에 Pods-Runner.profile.xcconfig 파일이 포함되어 있는지 확인

## Podfile 관련 문제 해결

[중요] pod install 명령어는 ios 디렉토리에서 실행해야 합니다.
오류 메시지 "No `Podfile` found in the project directory" 가 출력된다면 다음을 확인하세요:

1. 현재 작업 디렉토리가 프로젝트 루트가 아닌 ios 폴더인지 확인:
   cd ios
2. ios 디렉토리에 Podfile이 없으면, 아래 명령어로 필요한 iOS 파일들을 생성합니다:
   flutter pub get
   flutter create .

## Xcode 빌드 문제 해결

Xcode에서 "concurrent builds" 관련 오류가 발생하면 다음을 확인하세요:

- 다른 Xcode 인스턴스나 빌드 프로세스가 실행 중인지 확인 후 종료
- Xcode에서 Product > Scheme > Edit Scheme > Build 탭으로 이동 후 "Parallelize Build" 옵션을 비활성화
- 필요 시 Derived Data 폴더 정리 (Xcode > Preferences > Locations > Derived Data)

## PhaseScriptExecution 오류 해결

만약 "Command PhaseScriptExecution failed with a nonzero exit code" 오류가 발생한다면 아래 단계를 시도하세요:

1. Xcode에서 Product > Clean Build Folder 실행
2. Xcode Preferences > Locations에서 Derived Data 삭제
3. 터미널에서 프로젝트 루트에서 아래 명령 실행:
   flutter clean
   flutter pub get
4. 빌드 스크립트 내 출력 로그를 확인해 추가 오류 원인을 파악

## Project Root 관련 문제

오류 메시지 "Expected to find project root in current working directory."는 현재 작업 디렉토리에 프로젝트 루트에 해당하는 파일(예: pubspec.yaml)이 없음을 의미합니다.

- 터미널에서 /Users/user/StudioProjects/plangram 디렉토리로 이동 후 명령어 실행:
   cd /Users/user/StudioProjects/plangram
- 프로젝트 루트에 올바른 파일들이 존재하는지 확인 (pubspec.yaml 등)
