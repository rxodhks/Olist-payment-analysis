-- =====================================================================
-- 02_scope.sql  |  미션 2: 분석 범위 정하기
-- 질문: 어떤 기간과 주문 상태를 분석에 쓸 것인가?
-- =====================================================================

-- [2-1] 주문 상태별 건수와 비율 -------------------------------------------
-- delivered 96,478건 (약 97%)
SELECT order_status,
       COUNT(*)                                          AS order_cnt,
       ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 3)  AS pct
FROM raw_orders
GROUP BY order_status
ORDER BY order_cnt DESC;


-- [2-2] 월별 주문 수 ----------------------------------------------------
-- 초안: 월(MM)만 잘라서 서로 다른 해가 합쳐짐 → 모든 달이 4,000건 이상으로 보였음
-- SELECT SUBSTR(ORDER_PURCHASE_TIMESTAMP, 6, 2) || '월' AS MONTH,
--        COUNT(*) AS MONTH_COUNT
-- FROM RAW_ORDERS
-- GROUP BY SUBSTR(ORDER_PURCHASE_TIMESTAMP, 6, 2)
-- ORDER BY MONTH_COUNT;

-- 수정: 연-월(YYYY-MM) 기준, 시간 순 정렬
-- TODO: DataGrip에 저장한 실제 수정본과 대조할 것
SELECT SUBSTR(order_purchase_timestamp, 1, 7) AS purchase_month,
       COUNT(*)                               AS order_cnt
FROM raw_orders
GROUP BY SUBSTR(order_purchase_timestamp, 1, 7)
ORDER BY purchase_month;

-- 결과에서 확인한 것
--   2016-09: 4건, 2016-10: 324건, 2016-11: 0건(결과에 행이 없음), 2016-12: 1건
--   2018-09: 16건, 2018-10: 4건
-- 결정: 분석 기간 2017-01 ~ 2018-08
--   - 앞뒤 달의 극소수 주문은 수요가 아니라 데이터 수집 시작·종료의 경계 효과
--   - 2016-11이 0건이라 2016-10도 연속성이 끊긴 고립된 달
-- 결정: 분석 대상 주문은 delivered만 사용
--   - canceled, unavailable은 구매로 보지 않는다
