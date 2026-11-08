-- =====================================================================
-- 01_customer_id.sql  |  미션 1: 고객 ID 함정 찾기
-- 질문: 재구매 분석에는 customer_id와 customer_unique_id 중 무엇을 써야 하는가?
-- =====================================================================

-- [1-1] 고유 개수 비교 -------------------------------------------------
-- 원본 (Oracle 전용 문법 UNIQUE 사용)
-- SELECT COUNT(UNIQUE(CUSTOMER_UNIQUE_ID)), COUNT(UNIQUE(CUSTOMER_ID))
-- FROM RAW_CUSTOMERS;

-- 표준 SQL 버전
SELECT COUNT(DISTINCT customer_unique_id) AS unique_id_cnt,   -- 96,096
       COUNT(DISTINCT customer_id)        AS customer_id_cnt   -- 99,441
FROM raw_customers;

-- 참고: COUNT(컬럼)은 값이 있는 '행' 수를 세므로 둘 다 99,441이 나온다.


-- [1-2] ID 하나당 최대 주문 수 -----------------------------------------
-- customer_id 기준: 1건 → 주문마다 새로 발급되는 ID
SELECT MAX(cnt) AS max_orders_per_customer_id
FROM (
    SELECT customer_id, COUNT(*) AS cnt
    FROM raw_orders
    GROUP BY customer_id
);

-- customer_unique_id 기준: 17건 → 실제 한 사람
SELECT MAX(cnt) AS max_orders_per_person
FROM (
    SELECT c.customer_unique_id, COUNT(*) AS cnt
    FROM raw_orders o
    JOIN raw_customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
);


-- [1-3] 실행 계획 확인 --------------------------------------------------
-- 위 쿼리: Cost 3,857 (스캔 약 1,060 / HASH JOIN 582 / HASH GROUP BY 2,214)
-- Cost는 자식 단계를 포함한 누적값이므로 단계별 비용은 빼서 계산한다.
EXPLAIN PLAN FOR
SELECT MAX(cnt)
FROM (
    SELECT c.customer_unique_id, COUNT(*) AS cnt
    FROM raw_orders o
    JOIN raw_customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
);
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- 리뷰 과정에서 비교한 대안: JOIN 제거 (Cost 1,257)
-- 전제: RAW_CUSTOMERS의 행 1개 = 주문 1건. 전제가 깨지면 결과가 틀리므로
-- 분석용으로는 위의 JOIN 버전을 유지한다.
SELECT MAX(cnt)
FROM (
    SELECT customer_unique_id, COUNT(*) AS cnt
    FROM raw_customers
    GROUP BY customer_unique_id
);
