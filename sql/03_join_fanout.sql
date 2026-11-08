-- =====================================================================
-- 03_join_fanout.sql  |  미션 3: JOIN하면 매출이 왜 틀리는가
-- 질문: 주문·상품·결제를 그냥 JOIN해서 결제액을 합산하면 맞는가?
-- =====================================================================

-- [3-1] 세 테이블을 그냥 JOIN한 결제 합계 --------------------------------
-- 초안: ROUND가 SUM 안에 있어 건별 반올림 오차가 누적됨
-- SELECT SUM(ROUND(TO_NUMBER(PAYMENT_VALUE)))
-- FROM RAW_ORDER_PAYMENTS P
-- JOIN (SELECT O.ORDER_ID
--       FROM RAW_ORDERS O
--       JOIN RAW_ORDER_ITEMS I ON O.ORDER_ID = I.ORDER_ID
-- ) OI ON P.ORDER_ID = OI.ORDER_ID;

-- 수정: 다 더한 뒤 한 번만 반올림 + 행 수 함께 확인
-- 결과: 117,601행 / 20,308,134.71
SELECT COUNT(*)                                  AS row_cnt,
       ROUND(SUM(TO_NUMBER(p.payment_value)), 2) AS total_pay
FROM raw_orders o
JOIN raw_order_items i    ON i.order_id = o.order_id
JOIN raw_order_payments p ON p.order_id = o.order_id;


-- [3-2] 결제 테이블만으로 계산한 결제 합계 (정답) -------------------------
-- 결과: 103,886행 / 16,008,872.12
SELECT COUNT(*)                                AS row_cnt,
       ROUND(SUM(TO_NUMBER(payment_value)), 2) AS total_pay
FROM raw_order_payments;

-- 해석
--   - JOIN 결과가 26.9% 부풀었다. 상품 N개 × 결제 M건 = N×M행이 되기 때문
--     예) 상품 2개·결제 2건 주문(03ecec24...) → 4행, 375.73이 751.46으로 집계
--   - 동시에 INNER JOIN은 상품이 없는 주문의 결제 830행(162,591.95)을 버린다


-- [3-3] 올바른 방법: JOIN 전에 주문 단위로 먼저 집계 ----------------------
-- 결과: 98,665행 (주문당 1행)
--   상품이 있는 주문 98,666 중 결제 기록이 없는 1건이 INNER JOIN에서 빠짐
SELECT i.order_id, i.item_amt, p.pay_value
FROM (
    -- 주문별 상품 금액 합계 (item_amt)
    SELECT order_id, SUM(TO_NUMBER(price) + TO_NUMBER(freight_value)) AS item_amt
    FROM raw_order_items
    GROUP BY order_id
) i
JOIN (
    -- 주문별 결제 합계 (pay_value)
    SELECT order_id, SUM(TO_NUMBER(payment_value)) AS pay_value
    FROM raw_order_payments
    GROUP BY order_id
) p ON i.order_id = p.order_id;


-- [3-4] 상품 금액과 결제액이 1 BRL 넘게 다른 주문 --------------------------
-- 결과: 249건 (전체 98,665건 중 0.25%)
SELECT i.order_id, i.item_amt, p.pay_value
FROM (
    -- 주문별 상품 금액 합계 (item_amt)
    SELECT order_id, SUM(TO_NUMBER(price) + TO_NUMBER(freight_value)) AS item_amt
    FROM raw_order_items
    GROUP BY order_id
) i
JOIN (
    -- 주문별 결제 합계 (pay_value)
    SELECT order_id, SUM(TO_NUMBER(payment_value)) AS pay_value
    FROM raw_order_payments
    GROUP BY order_id
) p ON i.order_id = p.order_id
WHERE ABS(item_amt - pay_value) > 1;

-- 해석
--   - 결제액이 더 큰 232건 중 229건이 할부 → 할부 이자로 추정
--   - 불일치율: 할부(2개월 이상) 0.46% vs 일시불 0.027% (약 17배)
--   - 결제액이 더 작은 17건은 할인 수단 사용으로 추정 (미검증 가설)
-- 결정: 매출은 상품 금액(가격 + 배송비) 기준으로 정의한다
