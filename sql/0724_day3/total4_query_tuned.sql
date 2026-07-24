/*
 * 종합실습 4 - 튜닝 후 쿼리 및 추가 제출물
 *
 * 작업 환경
 * - Local PC에 설치한 PostgreSQL에서 실행합니다.
 *
 * 필수 제출물
 * 1. Q1~Q10 문항별 튜닝 전 쿼리와 결과 화면
 * 2. Q1~Q10 문항별 튜닝 후 쿼리와 결과 화면
 * 3. Materialized View 생성 스크립트와 실행 후 결과 화면
 *
 * 실행 순서
 * - 먼저 total4_01-05.sql과 total4_06-11.sql의 튜닝 전 실행 계획을 캡처합니다.
 * - 그 다음 이 파일의 공통 튜닝 인덱스를 생성하고 Q1~Q10을 실행합니다.
 */

-- ============================================================
-- 공통 튜닝 인덱스
-- - 기존 PK/FK 및 기본 인덱스는 유지하고 실습 쿼리에 필요한 인덱스만 추가합니다.
-- - 부분 인덱스로 실제 판매 주문만 저장하여 인덱스 크기를 줄입니다.
-- - 데이터가 작으면 PostgreSQL이 Index Scan보다 Seq Scan을 선택할 수 있습니다.
-- ============================================================

-- Q1/Q3/Q10: 판매 상태의 기간 검색 후 고객 및 주문상품 연결
CREATE INDEX IF NOT EXISTS idx_orders_sales_ts_customer
    ON ecom.orders (order_ts DESC, customer_id, order_id)
    INCLUDE (coupon_code)
    WHERE order_status IN ('paid', 'shipped', 'delivered');

-- Q5/Q6: 고객별 구매 이력 및 첫 구매/재구매 시각 검색
CREATE INDEX IF NOT EXISTS idx_orders_sales_customer_ts
    ON ecom.orders (customer_id, order_ts, order_id)
    WHERE order_status IN ('paid', 'shipped', 'delivered');

-- 다수 문항: order_id JOIN 후 상품, 금액을 테이블 재조회 없이 읽도록 보조
CREATE INDEX IF NOT EXISTS idx_order_items_order_cover
    ON ecom.order_items (order_id)
    INCLUDE (product_id, line_total);

-- Q7: 재주문 대상만 저장하고 부족 수량 순으로 탐색
CREATE INDEX IF NOT EXISTS idx_inventory_reorder_shortage
    ON ecom.inventory ((reorder_point - qty_on_hand) DESC, product_id)
    WHERE qty_on_hand < reorder_point;

-- Q8: 제품별 리뷰 집계 시 rating까지 인덱스에서 읽도록 보조
CREATE INDEX IF NOT EXISTS idx_reviews_product_rating_cover
    ON ecom.reviews (product_id)
    INCLUDE (rating);

-- 새 인덱스를 반영해 옵티마이저 통계 갱신
ANALYZE ecom.orders;
ANALYZE ecom.order_items;
ANALYZE ecom.inventory;
ANALYZE ecom.reviews;

-- ============================================================
-- Q1. 튜닝 후 쿼리
--     [제출] 튜닝 후 쿼리 및 실행 결과 화면
--     [비교] EXPLAIN ANALYZE로 튜닝 전후 실행 계획과 실행 시간 비교
--     [튜닝] 판매 상태+기간 부분 인덱스와 order_items 커버링 인덱스 활용
-- ============================================================

-- EXPLAIN (ANALYZE, BUFFERS)
SELECT
    COALESCE(SUM(oi.line_total), 0) AS total_sales_amount
FROM ecom.orders AS o
JOIN ecom.order_items AS oi
  ON oi.order_id = o.order_id
WHERE o.order_status IN ('paid', 'shipped', 'delivered')
  AND o.order_ts >= CURRENT_TIMESTAMP - INTERVAL '1 month';

-- ============================================================
-- Q2. 튜닝 후 쿼리
--     [제출] 튜닝 후 쿼리 및 실행 결과 화면
--     [비교] EXPLAIN ANALYZE로 튜닝 전후 실행 계획과 실행 시간 비교
--     [튜닝] 주문별 1회 선집계 후 월별로 재집계하여 중복 및 불필요한 계산 방지
-- ============================================================

-- EXPLAIN (ANALYZE, BUFFERS)
WITH order_totals AS (
    SELECT
        o.order_id,
        DATE_TRUNC('month', o.order_ts) AS order_month,
        SUM(oi.line_total) AS order_amount
    FROM ecom.orders AS o
    JOIN ecom.order_items AS oi
      ON oi.order_id = o.order_id
    WHERE o.order_status IN ('paid', 'shipped', 'delivered')
    GROUP BY
        o.order_id,
        DATE_TRUNC('month', o.order_ts)
)
SELECT
    order_month,
    COUNT(*) AS order_count,
    SUM(order_amount) AS total_sales_amount,
    AVG(order_amount) AS avg_order_amount
FROM order_totals
GROUP BY order_month
ORDER BY order_month;

-- ============================================================
-- Q3. 튜닝 후 쿼리
--     [제출] 튜닝 후 쿼리 및 실행 결과 화면
--     [비교] EXPLAIN ANALYZE로 튜닝 전후 실행 계획과 실행 시간 비교
--     [튜닝] 최근 90일 주문을 부분 인덱스로 먼저 줄인 뒤 카테고리 집계
-- ============================================================

-- EXPLAIN (ANALYZE, BUFFERS)
SELECT
    ct.category_id,
    ct.category_name,
    SUM(oi.line_total) AS category_sales_amount
FROM ecom.orders AS o
JOIN ecom.order_items AS oi
  ON oi.order_id = o.order_id
JOIN ecom.products AS p
  ON p.product_id = oi.product_id
JOIN ecom.categories AS ct
  ON ct.category_id = p.category_id
WHERE o.order_status IN ('paid', 'shipped', 'delivered')
  AND o.order_ts >= CURRENT_TIMESTAMP - INTERVAL '90 days'
GROUP BY
    ct.category_id,
    ct.category_name
ORDER BY category_sales_amount DESC
LIMIT 10;

-- ============================================================
-- Q4. 튜닝 후 쿼리
--     [제출] 튜닝 후 쿼리 및 실행 결과 화면
--     [비교] EXPLAIN ANALYZE로 튜닝 전후 실행 계획과 실행 시간 비교
--     [튜닝] 제품별 집계와 RANK 계산을 하나의 CTE에서 수행
-- ============================================================

-- EXPLAIN (ANALYZE, BUFFERS)
WITH ranked_products AS (
    SELECT
        p.product_id,
        p.product_name,
        SUM(oi.line_total) AS product_sales_amount,
        RANK() OVER (
            ORDER BY SUM(oi.line_total) DESC
        ) AS sales_rank
    FROM ecom.orders AS o
    JOIN ecom.order_items AS oi
      ON oi.order_id = o.order_id
    JOIN ecom.products AS p
      ON p.product_id = oi.product_id
    WHERE o.order_status IN ('paid', 'shipped', 'delivered')
    GROUP BY
        p.product_id,
        p.product_name
)
SELECT
    sales_rank,
    product_id,
    product_name,
    product_sales_amount
FROM ranked_products
WHERE sales_rank <= 20
ORDER BY sales_rank, product_id;

-- ============================================================
-- Q5. 튜닝 후 쿼리
--     [제출] 튜닝 후 쿼리 및 실행 결과 화면
--     [비교] EXPLAIN ANALYZE로 튜닝 전후 실행 계획과 실행 시간 비교
--     [튜닝] 주문별 CTE 없이 고객별로 한 번에 집계하고 주문 수는 DISTINCT 처리
-- ============================================================

-- EXPLAIN (ANALYZE, BUFFERS)
SELECT
    cust.customer_id,
    cust.full_name,
    cust.email,
    CURRENT_DATE - MAX(o.order_ts)::date AS recency,
    COUNT(DISTINCT o.order_id) AS frequency,
    SUM(oi.line_total) AS monetary
FROM ecom.orders AS o
JOIN ecom.order_items AS oi
  ON oi.order_id = o.order_id
JOIN ecom.customers AS cust
  ON cust.customer_id = o.customer_id
WHERE o.order_status IN ('paid', 'shipped', 'delivered')
GROUP BY
    cust.customer_id,
    cust.full_name,
    cust.email
ORDER BY monetary DESC;

-- ============================================================
-- Q6. 튜닝 후 쿼리
--     [제출] 튜닝 후 쿼리 및 실행 결과 화면
--     [비교] EXPLAIN ANALYZE로 튜닝 전후 실행 계획과 실행 시간 비교
--     [튜닝] 고객별 주문을 한 번 정렬하고 첫 번째와 두 번째 구매만 집계
-- ============================================================

-- EXPLAIN (ANALYZE, BUFFERS)
WITH sequenced_orders AS (
    SELECT
        o.customer_id,
        o.order_ts,
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id
            ORDER BY o.order_ts, o.order_id
        ) AS purchase_no
    FROM ecom.orders AS o
    WHERE o.order_status IN ('paid', 'shipped', 'delivered')
),
first_two_purchases AS (
    SELECT
        customer_id,
        MAX(order_ts) FILTER (WHERE purchase_no = 1) AS first_order_ts,
        MAX(order_ts) FILTER (WHERE purchase_no = 2) AS second_order_ts
    FROM sequenced_orders
    WHERE purchase_no <= 2
    GROUP BY customer_id
),
repurchase_flags AS (
    SELECT
        customer_id,
        second_order_ts <= first_order_ts + INTERVAL '30 days'
            AS repurchased_within_30d
    FROM first_two_purchases
    WHERE first_order_ts <= CURRENT_TIMESTAMP - INTERVAL '30 days'
)
SELECT
    COUNT(*) AS first_purchase_customers,
    COUNT(*) FILTER (
        WHERE repurchased_within_30d
    ) AS repurchase_customers,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE repurchased_within_30d)
        / NULLIF(COUNT(*), 0),
        2
    ) AS repurchase_rate_pct
FROM repurchase_flags;

-- ============================================================
-- Q7. 튜닝 후 쿼리
--     [제출] 튜닝 후 쿼리 및 실행 결과 화면
--     [비교] EXPLAIN ANALYZE로 튜닝 전후 실행 계획과 실행 시간 비교
--     [튜닝] 재주문 대상과 부족 수량을 미리 저장한 부분 표현식 인덱스 활용
-- ============================================================

-- EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.product_id,
    p.product_name,
    inven.qty_on_hand,
    inven.reorder_point,
    inven.reorder_point - inven.qty_on_hand AS need_qty
FROM ecom.inventory AS inven
JOIN ecom.products AS p
  ON p.product_id = inven.product_id
WHERE inven.qty_on_hand < inven.reorder_point
ORDER BY need_qty DESC;

-- ============================================================
-- Q8. 튜닝 후 쿼리
--     [제출] 튜닝 후 쿼리 및 실행 결과 화면
--     [비교] EXPLAIN ANALYZE로 튜닝 전후 실행 계획과 실행 시간 비교
--     [튜닝] product_id+rating 커버링 인덱스로 제품별 리뷰 집계 보조
-- ============================================================

-- EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.product_id,
    p.product_name,
    ROUND(AVG(rev.rating), 2) AS rating,
    COUNT(*) AS reviews_cnt
FROM ecom.reviews AS rev
JOIN ecom.products AS p
  ON p.product_id = rev.product_id
GROUP BY
    p.product_id,
    p.product_name
HAVING AVG(rev.rating) >= 4.5
   AND COUNT(*) >= 50
ORDER BY rating DESC, reviews_cnt DESC;

-- ============================================================
-- Q9. 튜닝 후 쿼리
--     [제출] 튜닝 후 쿼리 및 실행 결과 화면
--     [비교] EXPLAIN ANALYZE로 튜닝 전후 실행 계획과 실행 시간 비교
--     [튜닝] 주문별 금액을 한 번만 집계하고 쿠폰 사용 여부만 상위 집계
-- ============================================================

-- EXPLAIN (ANALYZE, BUFFERS)
WITH order_totals AS (
    SELECT
        o.order_id,
        o.coupon_code IS NOT NULL AS coupon_used,
        SUM(oi.line_total) AS order_amount
    FROM ecom.orders AS o
    JOIN ecom.order_items AS oi
      ON oi.order_id = o.order_id
    WHERE o.order_status IN ('paid', 'shipped', 'delivered')
    GROUP BY
        o.order_id,
        o.coupon_code
)
SELECT
    CASE
        WHEN coupon_used THEN 'coupon_used'
        ELSE 'no_coupon'
    END AS coupon_group,
    AVG(order_amount) AS avg_order_amount,
    COUNT(*) AS order_count
FROM order_totals
GROUP BY coupon_used
ORDER BY coupon_used DESC;

-- ============================================================
-- Q10. 튜닝 후 쿼리
--      [제출] 튜닝 후 쿼리 및 실행 결과 화면
--      [비교] EXPLAIN ANALYZE로 튜닝 전후 실행 계획과 실행 시간 비교
--      [튜닝] 최근 60일을 인덱스로 먼저 제한하고 고객별로 한 번만 집계
-- ============================================================

-- EXPLAIN (ANALYZE, BUFFERS)
WITH customer_sales AS (
    SELECT
        o.customer_id,
        SUM(oi.line_total) AS sales_60d
    FROM ecom.orders AS o
    JOIN ecom.order_items AS oi
      ON oi.order_id = o.order_id
    WHERE o.order_status IN ('paid', 'shipped', 'delivered')
      AND o.order_ts >= CURRENT_TIMESTAMP - INTERVAL '60 days'
    GROUP BY o.customer_id
),
ranked_customers AS (
    SELECT
        customer_id,
        sales_60d,
        NTILE(100) OVER (
            ORDER BY sales_60d DESC
        ) AS sales_group
    FROM customer_sales
)
SELECT
    rc.customer_id,
    cust.full_name,
    cust.email,
    rc.sales_60d
FROM ranked_customers AS rc
JOIN ecom.customers AS cust
  ON cust.customer_id = rc.customer_id
WHERE rc.sales_group = 1
ORDER BY rc.sales_60d DESC;

-- ============================================================
-- Materialized View 생성 및 실행
--    - 매일의 총 판매금액을 조회하는 mv_daily_gmv를 생성합니다.
--    - 매번 JOIN 후 SUM 하는 리포트 쿼리를 빠르게 실행하도록 구성합니다.
--    - 데이터 변경 주기에 맞춰 갱신 전략을 작성합니다.
--      예: 오후 3시 기준 갱신
--
-- [제출] CREATE MATERIALIZED VIEW 생성 스크립트
-- [제출] Materialized View 조회 쿼리와 실행 결과 화면
-- [확인] 필요하면 REFRESH MATERIALIZED VIEW 실행 및 결과 확인
-- ============================================================

-- 스키마 생성 스크립트에서 이미 만들어졌다면 NOTICE만 출력하고 건너뜁니다.
CREATE MATERIALIZED VIEW IF NOT EXISTS ecom.mv_daily_gmv AS
SELECT
    DATE_TRUNC('day', o.order_ts) AS day,
    SUM(oi.line_total) AS gmv
FROM ecom.orders AS o
JOIN ecom.order_items AS oi
  ON oi.order_id = o.order_id
WHERE o.order_status IN ('paid', 'shipped', 'delivered')
GROUP BY DATE_TRUNC('day', o.order_ts)
WITH DATA;

-- 날짜별 조회와 CONCURRENTLY 갱신을 위한 UNIQUE 인덱스
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_daily_gmv_day
    ON ecom.mv_daily_gmv (day);

-- 갱신 전략: 매일 오후 3시에 스케줄러에서 아래 문장을 실행합니다.
-- 일반 갱신은 실행 중 조회를 잠시 막을 수 있습니다.
REFRESH MATERIALIZED VIEW ecom.mv_daily_gmv;

-- 운영 환경에서 조회를 계속 허용해야 한다면 UNIQUE 인덱스 생성 후 사용합니다.
-- 주의: CONCURRENTLY는 트랜잭션 블록 안에서 실행할 수 없습니다.
-- REFRESH MATERIALIZED VIEW CONCURRENTLY ecom.mv_daily_gmv;

ANALYZE ecom.mv_daily_gmv;

-- Materialized View 실행 결과
-- EXPLAIN (ANALYZE, BUFFERS)
SELECT
    day,
    gmv
FROM ecom.mv_daily_gmv
ORDER BY day;

-- 최근 30일 리포트 조회 예시
-- EXPLAIN (ANALYZE, BUFFERS)
SELECT
    day,
    gmv
FROM ecom.mv_daily_gmv
WHERE day >= DATE_TRUNC('day', CURRENT_TIMESTAMP) - INTERVAL '30 days'
ORDER BY day;
