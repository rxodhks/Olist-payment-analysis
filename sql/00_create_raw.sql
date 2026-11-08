-- =====================================================================
-- 00_create_raw.sql  |  원천(raw) 테이블 생성
-- 대상: Oracle AI Database 26ai (23.26)
--
-- 설계 원칙
--   1) 원천 값은 모두 VARCHAR2로 받는다. 타입 변환은 다음 단계에서 한다.
--      (예: 우편번호 '01003'처럼 0으로 시작하는 값 23,995건을 보존)
--   2) PK/FK/CHECK는 실제 데이터로 먼저 검증한 것만 건다.
--   3) RAW_PRODUCTS의 카테고리 FK는 걸지 않는다.
--      번역표에 없는 카테고리 2종(상품 13개)이 있어 적재가 실패하기 때문.
--
-- 적재 순서 (FK 때문에 부모 → 자식, 어기면 ORA-02291)
--   1. RAW_CUSTOMERS, RAW_SELLERS, RAW_CATEGORY_TRANSLATION
--   2. RAW_PRODUCTS
--   3. RAW_ORDERS
--   4. RAW_ORDER_ITEMS, RAW_ORDER_PAYMENTS, RAW_ORDER_REVIEWS
-- =====================================================================

-- 1) 부모 테이블 -------------------------------------------------------
CREATE TABLE RAW_CUSTOMERS (
    customer_id               VARCHAR2(32),
    customer_unique_id        VARCHAR2(32),
    customer_zip_code_prefix  VARCHAR2(10),
    customer_city             VARCHAR2(100),
    customer_state            VARCHAR2(2),
    CONSTRAINT pk_raw_customers PRIMARY KEY (customer_id),
    CONSTRAINT ck_raw_customers_state CHECK (LENGTH(customer_state) = 2)
);

CREATE TABLE RAW_SELLERS (
    seller_id               VARCHAR2(32),
    seller_zip_code_prefix  VARCHAR2(10),
    seller_city             VARCHAR2(100),
    seller_state            VARCHAR2(2),
    CONSTRAINT pk_raw_sellers PRIMARY KEY (seller_id),
    CONSTRAINT ck_raw_sellers_state CHECK (LENGTH(seller_state) = 2)
);

CREATE TABLE RAW_CATEGORY_TRANSLATION (
    product_category_name          VARCHAR2(100),
    product_category_name_english  VARCHAR2(100),
    CONSTRAINT pk_raw_category_translation PRIMARY KEY (product_category_name)
);

-- 2) 상품 -------------------------------------------------------------
-- 원본 CSV의 컬럼명 오타(lenght)를 length로 고쳐서 생성했다.
-- Import할 때 이 두 컬럼은 수동으로 매핑해야 한다.
CREATE TABLE RAW_PRODUCTS (
    product_id                  VARCHAR2(32),
    product_category_name       VARCHAR2(100),
    product_name_length         VARCHAR2(10),
    product_description_length  VARCHAR2(10),
    product_photos_qty          VARCHAR2(10),
    product_weight_g            VARCHAR2(10),
    product_length_cm           VARCHAR2(10),
    product_height_cm           VARCHAR2(10),
    product_width_cm            VARCHAR2(10),
    CONSTRAINT pk_raw_products PRIMARY KEY (product_id)
);

-- 3) 주문 -------------------------------------------------------------
CREATE TABLE RAW_ORDERS (
    order_id                       VARCHAR2(32),
    customer_id                    VARCHAR2(32),
    order_status                   VARCHAR2(100),
    order_purchase_timestamp       VARCHAR2(20) NOT NULL,
    order_approved_at              VARCHAR2(20),
    order_delivered_carrier_date   VARCHAR2(20),
    order_delivered_customer_date  VARCHAR2(20),
    order_estimated_delivery_date  VARCHAR2(20),
    CONSTRAINT pk_raw_orders PRIMARY KEY (order_id),
    CONSTRAINT fk_raw_orders_customer FOREIGN KEY (customer_id)
        REFERENCES raw_customers (customer_id),
    CONSTRAINT ck_raw_orders_status CHECK (order_status IN (
        'approved', 'canceled', 'created', 'delivered',
        'invoiced', 'processing', 'shipped', 'unavailable'))
);

-- 4) 주문 하위 테이블 -------------------------------------------------
CREATE TABLE RAW_ORDER_ITEMS (
    order_id             VARCHAR2(32),
    order_item_id        VARCHAR2(10),
    product_id           VARCHAR2(32),
    seller_id            VARCHAR2(32),
    shipping_limit_date  VARCHAR2(20),
    price                VARCHAR2(20),
    freight_value        VARCHAR2(20),
    CONSTRAINT pk_raw_order_items PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_raw_items_order FOREIGN KEY (order_id)
        REFERENCES raw_orders (order_id),
    CONSTRAINT fk_raw_items_product FOREIGN KEY (product_id)
        REFERENCES raw_products (product_id),
    CONSTRAINT fk_raw_items_seller FOREIGN KEY (seller_id)
        REFERENCES raw_sellers (seller_id)
);

CREATE TABLE RAW_ORDER_PAYMENTS (
    order_id              VARCHAR2(32),
    payment_sequential    VARCHAR2(10),
    payment_type          VARCHAR2(100),
    payment_installments  VARCHAR2(20),
    payment_value         VARCHAR2(20),
    CONSTRAINT pk_raw_order_payments PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_raw_payments_order FOREIGN KEY (order_id)
        REFERENCES raw_orders (order_id),
    CONSTRAINT ck_raw_payments_type CHECK (payment_type IN (
        'boleto', 'credit_card', 'debit_card', 'not_defined', 'voucher'))
);

-- review_id 단독은 PK가 될 수 없다 (같은 리뷰가 여러 주문에 걸려 있음)
CREATE TABLE RAW_ORDER_REVIEWS (
    review_id                VARCHAR2(32),
    order_id                 VARCHAR2(32),
    review_score             VARCHAR2(2),
    review_comment_title     VARCHAR2(400),
    review_comment_message   VARCHAR2(4000),
    review_creation_date     VARCHAR2(20),
    review_answer_timestamp  VARCHAR2(20),
    CONSTRAINT pk_raw_order_reviews PRIMARY KEY (review_id, order_id),
    CONSTRAINT fk_raw_reviews_order FOREIGN KEY (order_id)
        REFERENCES raw_orders (order_id),
    CONSTRAINT ck_raw_reviews_score CHECK (review_score IN ('1', '2', '3', '4', '5'))
);

-- 적재 후 확인: 8개 테이블 행 수가 원천 CSV와 같아야 한다
SELECT 'RAW_CUSTOMERS' AS tbl, COUNT(*) AS n, 99441 AS expected FROM raw_customers UNION ALL
SELECT 'RAW_SELLERS',              COUNT(*), 3095   FROM raw_sellers UNION ALL
SELECT 'RAW_CATEGORY_TRANSLATION', COUNT(*), 71     FROM raw_category_translation UNION ALL
SELECT 'RAW_PRODUCTS',             COUNT(*), 32951  FROM raw_products UNION ALL
SELECT 'RAW_ORDERS',               COUNT(*), 99441  FROM raw_orders UNION ALL
SELECT 'RAW_ORDER_ITEMS',          COUNT(*), 112650 FROM raw_order_items UNION ALL
SELECT 'RAW_ORDER_PAYMENTS',       COUNT(*), 103886 FROM raw_order_payments UNION ALL
SELECT 'RAW_ORDER_REVIEWS',        COUNT(*), 100000 FROM raw_order_reviews;
