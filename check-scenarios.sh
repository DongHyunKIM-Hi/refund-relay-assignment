#!/usr/bin/env bash
# 시나리오 자동 확인 (S1~S13)
#
# 사용법
#   1) 가상 결제대행사 실행:  docker compose up -d     (9090)
#   2) 구현한 서버 실행:      ./gradlew bootRun        (8080)
#   3) bash check-scenarios.sh
#
# - 실행할 때마다 새 ID를 쓰므로 서버를 재시작하지 않고 몇 번이든 돌릴 수 있습니다.
# - 처리(워커) 시나리오가 재시도를 끝낼 때까지 상태를 폴링하므로, 머신이 느려도
#   결과가 흔들리지 않습니다. 응답 지연(S10)이 가장 오래 걸려 전체 약 30~40초입니다.
# - 가상 결제대행사의 시나리오 재현 API(/sandbox)를 사용합니다. (README 참고)
# - 윈도우(Git Bash 등)에서 curl이 줄 끝에 캐리지리턴(\r)을 붙여도 비교가 깨지지 않도록
#   응답을 받는 곳에서 \r을 제거합니다.

S=${SERVER_URL:-http://localhost:8080}
P=${PG_URL:-http://localhost:9090}
H='Content-Type: application/json'

res1=""; res2=""; res3=""; res4=""; res5=""; res6=""; res7=""
res8=""; res9=""; res10=""; res11=""; res12=""; res13=""
PASS=0; FAIL=0

ok(){ eval "res$1=\"\$(printf '\033[32m[통과]\033[0m S%-3s %s' \"$1\" \"$2\")\""; PASS=$((PASS+1)); }
no(){ eval "res$1=\"\$(printf '\033[31m[실패]\033[0m S%-3s %s — %s' \"$1\" \"$2\" \"$3\")\""; FAIL=$((FAIL+1)); }
code(){ curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@" | tr -d '\r'; }
pin(){ curl -s -o /dev/null -X POST "$P/sandbox/scenario" -H "$H" -d "{\"refundId\":\"$1\",\"case\":\"$2\"}"; }
accept(){ curl -s -o /dev/null -w '%{http_code}\n' --max-time 15 -X POST "$S/api/v1/refunds" -H "$H" \
  -d "{\"refundId\":\"$1\",\"orderId\":\"$2\",\"paidAmount\":10000,\"refundAmount\":$3}" | tr -d '\r'; }
field(){ printf '%s' "$1" | tr -d '\r' | sed -n "s/.*\"$2\":\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p" | head -1; }

# 종결 상태(COMPLETED/FAILED)가 될 때까지 폴링한다. 최대 50초.
# 머신 속도와 무관하게 "재시도가 다 끝난 뒤의 상태"를 보게 해 준다.
wait_done(){
  local id="$1" i st body
  for i in $(seq 1 100); do
    body=$(curl -s "$S/api/v1/refunds/$id")
    st=$(field "$body" status)
    if [ "$st" = "COMPLETED" ] || [ "$st" = "FAILED" ]; then WD_BODY=$body; return 0; fi
    sleep 0.5
  done
  WD_BODY=$body; return 1
}
# 결제대행사에 처리 기록이 남을 때까지 폴링한다. 최대 50초.
wait_pg(){
  local id="$1" i pa
  for i in $(seq 1 100); do
    pa=$(field "$(curl -s "$P/pg/refunds/$id")" processedAt)
    if [ -n "$pa" ]; then WP_AT=$pa; return 0; fi
    sleep 0.5
  done
  WP_AT=""; return 1
}

echo "서버(8080)와 가상 결제대행사(9090) 연결을 확인합니다..."
[ "$(code "$S/api/v1/refunds/PING-0")" = "000" ] && { echo "서버에 연결할 수 없습니다. ./gradlew bootRun 후 다시 실행해 주세요."; exit 1; }
[ "$(code -X POST "$P/sandbox/reset")" = "000" ] && { echo "가상 결제대행사에 연결할 수 없습니다. docker compose up -d 후 다시 실행해 주세요."; exit 1; }

R=$RANDOM$RANDOM

# ---- 1) 접수 분기 (순차, 빠름) ----
ID1="R1-$R"; O1="ORD-S1-$R"
pin "$ID1" SUCCESS
c=$(accept "$ID1" "$O1" 3000)
[ "$c" = "202" ] && ok 1 "정상 접수 202" || no 1 "정상 접수 202" "응답 $c"

r=$(curl -s -w '\n%{http_code}' -X POST "$S/api/v1/refunds" -H "$H" \
  -d "{\"refundId\":\"$ID1\",\"orderId\":\"$O1\",\"paidAmount\":10000,\"refundAmount\":3000}")
c=${r##*$'\n'}; b=${r%$'\n'*}
if [ "$c" = "200" ] && printf '%s' "$b" | grep -q '"duplicate":true'; then ok 2 "같은 ID 같은 내용 200 duplicate"
else no 2 "같은 ID 같은 내용 200 duplicate" "응답 $c"; fi

c=$(accept "$ID1" "$O1" 9999)
[ "$c" = "409" ] && ok 3 "같은 ID 다른 내용 409" || no 3 "같은 ID 다른 내용 409" "응답 $c"

ID5="R5-$R"
c=$(accept "$ID5" "$O1" 8000)
st=$(field "$(curl -s "$S/api/v1/refunds/$ID5")" status)
if [ "$c" = "422" ] && [ "$st" = "REJECTED" ]; then ok 5 "한도 초과 422, REJECTED 저장"
else no 5 "한도 초과 422, REJECTED 저장" "응답 $c, 상태 ${st:-없음}"; fi

c1=$(accept "R7A-$R" "ORD-S7-$R" 0)
c2=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$S/api/v1/refunds" -H "$H" \
  -d "{\"orderId\":\"ORD-S7-$R\",\"paidAmount\":10000,\"refundAmount\":1000}")
if [ "$c1" = "400" ] && [ "$c2" = "400" ]; then ok 7 "입력 오류 400 (금액 0, 필수값 누락)"
else no 7 "입력 오류 400" "금액0=$c1, 누락=$c2"; fi

# ---- 2) 조회 ----
r=$(curl -s -w '\n%{http_code}' "$S/api/v1/refunds?orderId=$O1&page=0&size=20")
c=${r##*$'\n'}; b=${r%$'\n'*}
total=$(field "$b" totalElements)
first=$(printf '%s' "$b" | grep -o '"refundId":"[^"]*"' | head -1 | sed 's/.*:"//;s/"$//')
c404=$(code "$S/api/v1/refunds/NO-SUCH-$R")
if [ "$c" = "200" ] && [ "$total" = "2" ] && [ "$first" = "$ID5" ] && [ "$c404" = "404" ]; then
  ok 13 "주문별 목록(최신순, 2건) + 없는 ID 404"
else no 13 "주문별 목록 + 없는 ID 404" "목록 $c(${total:-?}건, 첫 항목 ${first:-없음}), 404 확인 $c404"; fi

# ---- 3) 동시 요청 (응답 코드로 즉시 판정) ----
ID4="R4-$R"; O4="ORD-S4-$R"; pin "$ID4" SUCCESS
codes4=$( ( for i in 1 2 3 4 5; do accept "$ID4" "$O4" 1000 & done; wait ) )
c=$(code "$S/api/v1/refunds/$ID4")
if [ "$c" = "200" ]; then ok 4 "같은 ID 동시 5건 → 1건만 저장"
else no 4 "같은 ID 동시 5건 → 1건만 저장" "단건 조회 $c (여러 건 저장됨)"; fi

O6="ORD-S6-$R"
codes6=$( ( accept "R6A-$R" "$O6" 4000 & accept "R6B-$R" "$O6" 4000 & accept "R6C-$R" "$O6" 4000 & wait ) )
sorted6=$(printf '%s\n' "$codes6" | tr -d '\r' | sort | tr '\n' ' ' | sed 's/ *$//')
if [ "$sorted6" = "202 202 422" ]; then ok 6 "같은 주문 동시 3건 → 한도 안에서만 승인 (202 202 422)"
else no 6 "같은 주문 동시 3건 → 한도 안에서만 승인" "응답 [$sorted6] (기대 202 202 422)"; fi

# ---- 4) 처리(워커) 시나리오: 한가한 워커 풀에서 접수하고 종결까지 폴링한다 ----
echo "처리(워커) 시나리오를 확인합니다. 재시도가 끝날 때까지 폴링하므로 30~40초 걸립니다..."
ID8="R8-$R";   pin "$ID8"  SUCCESS;               accept "$ID8"  "ORD-S8-$R"  1000 >/dev/null
ID9="R9-$R";   pin "$ID9"  ALWAYS_FAIL;           accept "$ID9"  "ORD-S9-$R"  1000 >/dev/null
ID10="R10-$R"; pin "$ID10" ALWAYS_TIMEOUT;        accept "$ID10" "ORD-S10-$R" 1000 >/dev/null
ID12="R12-$R"; pin "$ID12" TIMEOUT_BUT_PROCESSED; accept "$ID12" "ORD-S12-$R" 1000 >/dev/null
A11="R11A-$R"; B11="R11B-$R"; O11="ORD-S11-$R"
pin "$A11" TIMEOUT_THEN_SUCCESS; pin "$B11" SUCCESS
accept "$A11" "$O11" 1000 >/dev/null
accept "$B11" "$O11" 1000 >/dev/null

wait_done "$ID8"; st=$(field "$WD_BODY" status); at=$(field "$WD_BODY" attemptCount)
if [ "$st" = "COMPLETED" ] && [ "$at" = "1" ]; then ok 8 "성공 응답 → COMPLETED (시도 1회)"
else no 8 "성공 응답 → COMPLETED (시도 1회)" "상태 ${st:-없음}, 시도 ${at:-?}회"; fi

wait_done "$ID9"; st=$(field "$WD_BODY" status); at=$(field "$WD_BODY" attemptCount); fr=$(field "$WD_BODY" failureReason)
if [ "$st" = "FAILED" ] && [ "$at" = "4" ] && [ "$fr" = "PG_DECLINED" ]; then ok 9 "거절 응답 → 재시도 4회 후 FAILED, PG_DECLINED"
else no 9 "거절 응답 → 재시도 4회 후 FAILED, PG_DECLINED" "상태 ${st:-없음}, 시도 ${at:-?}회, 사유 ${fr:-없음}"; fi

wait_done "$ID10"; st=$(field "$WD_BODY" status); at=$(field "$WD_BODY" attemptCount); fr=$(field "$WD_BODY" failureReason)
if [ "$st" = "FAILED" ] && [ "$at" = "4" ] && [ "$fr" = "PG_TIMEOUT" ]; then ok 10 "응답 지연 → 시간 초과 재시도 4회 후 FAILED, PG_TIMEOUT"
else no 10 "응답 지연 → 시간 초과 재시도 후 FAILED, PG_TIMEOUT" "상태 ${st:-없음}, 시도 ${at:-?}회, 사유 ${fr:-없음}"; fi

# S11: 같은 주문의 두 건이 결제대행사에 전달된 순서. 앞 건(A, 느림)이 먼저여야 통과.
wait_pg "$A11"; pa=$WP_AT
wait_pg "$B11"; pb=$WP_AT
if [ -z "$pa" ] || [ -z "$pb" ]; then
  no 11 "같은 주문은 순서대로 처리" "처리 기록 없음 (앞 건: ${pa:-없음} / 뒤 건: ${pb:-없음})"
elif [ "$pa" \< "$pb" ] || [ "$pa" = "$pb" ]; then
  ok 11 "같은 주문은 순서대로 처리 (앞 건이 먼저 결제대행사에 전달)"
else
  no 11 "같은 주문은 순서대로 처리" "뒤 건이 앞 건보다 먼저 처리됨"
fi

wait_done "$ID12"; st=$(field "$WD_BODY" status)
pcount=$(curl -s "$P/sandbox/processed" | grep -o "\"ORD-S12-$R\":[0-9]*" | grep -o '[0-9]*$')
if [ "$st" = "COMPLETED" ] && [ "${pcount:-0}" = "1" ]; then ok 12 "지연됐지만 처리된 건 → COMPLETED, 환불은 정확히 1번"
else no 12 "지연됐지만 처리된 건 → COMPLETED, 환불 1번" "상태 ${st:-없음}, 처리 ${pcount:-0}번"; fi

# ---- 결과 ----
echo; echo "================ 시나리오 확인 결과 ================"
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13; do eval "printf '%b\n' \"\$res$i\""; done
echo "===================================================="
echo "통과 $PASS / 13"
[ "$FAIL" -gt 0 ] && echo "실패한 시나리오는 README의 시나리오 목록에서 해당 항목을 확인해 주세요."
exit 0
