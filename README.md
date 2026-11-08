# 결제 데이터 분석: 지표를 왜곡하는 함정 찾기

<!-- TODO(직접 작성): 이 프로젝트를 한 문장으로 요약하세요. 결과부터 씁니다.
     예시 구조: "[데이터]에서 [무엇]을 SQL로 찾아 [어떤 기준]을 설계했다" -->

> 진행 상황: 1단계(데이터 적재 · 정합성 검증) 진행 중 — 미션 0~3 완료

## 핵심 발견

| 발견 | 숫자 | 근거 쿼리 |
| --- | --- | --- |
| `customer_id`는 사람이 아니라 주문 단위 ID | ID당 최대 주문 1건 vs `customer_unique_id` 17건 | [`01_customer_id.sql`](sql/01_customer_id.sql) |
| 1:N 테이블을 그냥 JOIN하면 매출이 부풂 | 결제 합계 16,008,872 → 20,308,135 (+26.9%) | [`03_join_fanout.sql`](sql/03_join_fanout.sql) |
| 상품 금액과 결제액의 불일치는 할부와 관련 | 불일치율 할부 0.46% vs 일시불 0.027% | [`03_join_fanout.sql`](sql/03_join_fanout.sql) |

<!-- TODO(직접 작성): 각 발견이 왜 중요한지 한두 문장씩 덧붙이세요. -->

## 데이터와 환경

- 데이터: [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (주문 99,441건, 2016-09 ~ 2018-10, CC BY-NC-SA 4.0)
- DB: Oracle AI Database 26ai
- 도구: DataGrip
- 데이터 파일은 저장소에 포함하지 않습니다. 위 링크에서 받아 `sql/00_create_raw.sql`의 순서대로 적재합니다.

<!-- TODO: ERD 이미지를 docs/erd.png로 넣고 아래 줄의 주석을 해제하세요. -->
<!-- ![ERD](docs/erd.png) -->

## 분석 기준

자세한 정의와 근거는 [`docs/metric_definitions.md`](docs/metric_definitions.md)에 있습니다.

| 항목 | 기준 |
| --- | --- |
| 분석 기간 | 2017-01 ~ 2018-08 |
| 분석 대상 주문 | `delivered` 상태만 |
| 고객 단위 | `customer_unique_id` |
| 매출 | 상품 금액(가격 + 배송비) |

## 분석 과정

각 장면은 문제 → 가설 → 검증 → 결론 순서로 정리합니다.

### 1. 원천 테이블 설계와 제약 검증 — [`00_create_raw.sql`](sql/00_create_raw.sql)

<!-- TODO(직접 작성)
- 문제:
- 설계:
- 검증: 우편번호 앞자리 0 보존 23,995건 / 번역 없는 카테고리 2종(상품 13개)
- 결론:
-->

### 2. 고객 ID 함정 — [`01_customer_id.sql`](sql/01_customer_id.sql)

<!-- TODO(직접 작성): 처음 가설이 틀렸던 과정도 그대로 쓰세요.
- 문제:
- 처음 가설:
- 검증: customer_id 최대 1건 / customer_unique_id 최대 17건 / 2건 이상 주문자 2,997명
- 결론:
-->

### 3. 실행 계획 읽기 — [`01_customer_id.sql`](sql/01_customer_id.sql)

<!-- TODO(직접 작성)
- 검증: Cost 3,857 (스캔 약 1,060 / HASH JOIN 582 / HASH GROUP BY 2,214), JOIN 제거 시 1,257
- 결론:
-->

### 4. 분석 범위 결정 — [`02_scope.sql`](sql/02_scope.sql)

<!-- TODO(직접 작성)
- 처음 시도: 월(MM)만 잘라 연도가 합쳐짐
- 검증: 2016-09 4건, 2016-11 0건, 2016-12 1건, 2018-09 16건, 2018-10 4건
- 결론:
-->

### 5. JOIN 부풀림 — [`03_join_fanout.sql`](sql/03_join_fanout.sql)

<!-- TODO(직접 작성)
- 검증: 103,886행·16,008,872.12 vs JOIN 117,601행·20,308,134.71 / 누락 830행·162,591.95
- 해결: 주문 단위로 먼저 집계한 뒤 JOIN → 98,665행
- 결론:
-->

### 6. 금액 불일치 원인과 매출 정의 — [`03_join_fanout.sql`](sql/03_join_fanout.sql)

<!-- TODO(직접 작성)
- 가설:
- 검증: 불일치 249건 중 232건이 결제액이 더 큼, 그중 229건이 할부
- 결론:
-->

## 다음 단계

- [ ] 미션 4: 주문당 리뷰 1건만 남기기
- [ ] 미션 5: 고객별 구매 회차와 재구매율
- [ ] 미션 6: 코호트 리텐션 · LTV
- [ ] 미션 7: 정합성 검증 쿼리
- [ ] 미션 8: Tableau 대시보드

## 폴더 구조

```
olist-payment-analysis/
├── README.md
├── sql/
│   ├── 00_create_raw.sql      원천 테이블 생성 (PK·FK·CHECK)
│   ├── 01_customer_id.sql     고객 ID 함정, 실행 계획
│   ├── 02_scope.sql           분석 범위 결정
│   └── 03_join_fanout.sql     JOIN 부풀림, 금액 불일치
├── docs/
│   └── metric_definitions.md  분석 기준과 지표 정의서
└── images/                    실행 계획, 결과 캡처
```
