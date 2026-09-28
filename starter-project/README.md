# 환불 요청 중계 서버 — 시작 프로젝트

과제 설명은 상위 폴더의 `README.md`(가이드)를 먼저 읽어 주세요. 이 프로젝트는 빌드 설정(Java 17, Spring Boot 4.1.1, Gradle, JPA + H2)만 갖춘 빈 프로젝트입니다. 도메인 코드는 없습니다 — 여러분이 처음부터 만듭니다.

## 실행

```
./gradlew bootRun
```

기본 포트는 `8080`입니다. 가상 결제대행사(`../compose.yaml`)가 `9090`에서 먼저 떠 있어야 합니다.

## 결제대행사 주소 바꾸기

```
PG_BASE_URL=http://localhost:9091 ./gradlew bootRun
```

기본값은 `http://localhost:9090`입니다.

## 제출 전 체크

- [ ] `docs/design.md`를 채웠는가 (`../docs-template/design.md`를 복사해서 시작하세요)
- [ ] `./gradlew test`가 통과하는가
- [ ] `requests.http`의 모든 시나리오가 가이드의 기대 결과와 같은가
