# 환불 요청 중계 서버 시작 프로젝트

- 과제 설명은 상위 폴더의 `README.md`를 먼저 읽어 주세요.
- 이 프로젝트에는 빌드 설정(Java 17, Spring Boot 4.1.1, Gradle, JPA, H2)만 있고 도메인 코드는 없습니다.
- 이 폴더를 제출 저장소의 루트로 사용합니다.

## 실행

```bash
./gradlew bootRun
```

- 포트는 `8080`입니다.
- 가상 결제대행사(`../compose.yaml`)를 `9090` 포트로 먼저 실행해 두어야 합니다.

## 결제대행사 주소 바꾸기

결제대행사 주소는 환경변수 `PG_BASE_URL`로 바꿀 수 있게 구현해 주세요. 기본값은 `http://localhost:9090`입니다.

```bash
PG_BASE_URL=http://localhost:9999 ./gradlew bootRun
```

## 제출 전 확인 사항

- [ ] `docs/design.md`를 작성했다 (`../docs-template/design.md`를 복사해서 시작)
- [ ] `./gradlew test`가 통과한다
- [ ] `../requests.http`의 시나리오가 README의 기대 결과와 같다
