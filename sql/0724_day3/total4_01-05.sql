/*
 * 종합실습 4 - 실습 문제 Q1~Q5 (튜닝 전)
 *
 * 작업 환경 및 제출 항목
 * - Local PC에 설치한 PostgreSQL에서 실행합니다.
 * - 각 문항의 튜닝 전 쿼리를 이 파일에 작성합니다.
 * - 각 문항별로 쿼리와 실행 결과가 함께 보이도록 화면을 캡처합니다.
 *
 * 작성 시 유의사항
 * - 요구사항에 필요한 컬럼만 조회합니다.
 * - DB 프로그래밍에 대한 주석을 작성합니다.
 * - 튜닝 후 쿼리는 total4_query_tuned.sql에 작성합니다.
 */

-- ============================================================
-- Q1. 지난 한 달간 실제 팔린 총 금액 보기
--     - 주문 상태: paid, shipped, delivered
--     [제출] 튜닝 전 쿼리 및 실행 결과 화면
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    COALESCE(SUM(oi.line_total), 0) AS total_sales_amount
FROM ecom.orders AS o
JOIN ecom.order_items AS oi
  ON oi.order_id = o.order_id
WHERE o.order_status IN ('paid', 'shipped', 'delivered')
  AND o.order_ts >= CURRENT_TIMESTAMP - INTERVAL '1 month';

-- ============================================================
-- Q2. 월별 주문 성과 보기
--     - 월별 주문 수
--     - 월별 총 매출액
--     - 주문당 평균 금액
--     [제출] 튜닝 전 쿼리 및 실행 결과 화면
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS)
WITH order_totals AS (
    SELECT 
        o.order_id, 
        date_trunc('month', o.order_ts) AS order_month, 
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
-- Q3. 최근 90일 카테고리 Top 10
--     [제출] 튜닝 전 쿼리 및 실행 결과 화면
--
--     [힌트]
--     1. 필요한 테이블의 연결 순서를 생각해 보세요.
--        orders → order_items → products → categories
--     2. 각 테이블의 연결 키는 다음과 같습니다.
--        - orders.order_id = order_items.order_id
--        - order_items.product_id = products.product_id
--        - products.category_id = categories.category_id
--     3. Q1과 같은 실제 판매 주문 상태 조건을 사용합니다.
--     4. 최근 90일 조건은 order_ts와 INTERVAL '90 days'를 이용합니다.
--     5. 카테고리별로 GROUP BY한 뒤 SUM(line_total)로 매출을 구합니다.
--     6. 카테고리 매출의 내림차순으로 정렬하고 LIMIT 10을 적용합니다.
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    ct.category_id, 
    ct.category_name,
    SUM(oi.line_total) AS category_sales_amount
FROM ecom.orders AS o
JOIN ecom.order_items AS oi ON oi.order_id = o.order_id
JOIN ecom.products AS p ON p.product_id = oi.product_id
JOIN ecom.categories AS ct ON ct.category_id = p.category_id
WHERE o.order_status IN ('paid', 'shipped', 'delivered')
    AND o.order_ts >= CURRENT_TIMESTAMP - INTERVAL '90 days'
GROUP BY
    ct.category_id, 
    ct.category_name
ORDER BY category_sales_amount DESC
LIMIT 10;

-- ============================================================
-- Q4. 제품별 누적 매출 순위 Top 20
--     - RANK() 윈도우 함수를 사용합니다.
--     [제출] 튜닝 전 쿼리 및 실행 결과 화면
--
--     [힌트]
--     1. orders → order_items → products 순서로 테이블을 연결합니다.
--     2. Q1과 같은 실제 판매 주문 상태만 포함합니다.
--     3. 먼저 제품별 누적 매출 SUM(line_total)을 계산합니다.
--        product_id와 product_name을 함께 GROUP BY해 보세요.
--     4. 제품별 집계 결과를 CTE로 만든 뒤 다음 형태의 윈도우 함수를 적용합니다.
--        RANK() OVER (ORDER BY 누적매출 DESC)
--     5. 윈도우 함수 결과는 같은 SELECT의 WHERE에서 바로 필터링할 수 없습니다.
--        순위까지 계산한 결과를 한 번 더 CTE 또는 서브쿼리로 감싸세요.
--     6. 최종 결과에서 순위가 20 이하인 제품만 조회합니다.
--        RANK()는 동점 때문에 결과 행이 20개보다 많아질 수 있습니다.
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS)
WITH product_sales AS (
    SELECT 
        p.product_id, 
        p.product_name,
        SUM(oi.line_total) AS product_sales_amount
    FROM ecom.orders AS o
    JOIN ecom.order_items AS oi on oi.order_id = o.order_id
    JOIN ecom.products AS p on p.product_id = oi.product_id
    WHERE o.order_status IN ('paid', 'shipped', 'delivered')
    GROUP BY p.product_id, p.product_name
),
ranked_products AS (
    SELECT 
        product_id, 
        product_name, 
        product_sales_amount, 
        RANK() OVER (
            ORDER BY product_sales_amount DESC
        ) AS sales_rank
    FROM product_sales
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
-- Q5. 고객별 RFM 분석
--     - Recency: 고객이 얼마나 최근에 구매했는지
--     - Frequency: 고객이 얼마나 자주 구매했는지
--     - Monetary: 고객이 얼마나 많이 구매했는지
--     [제출] 튜닝 전 쿼리 및 실행 결과 화면
--
--     [힌트]
--     1. 실제 판매 주문만 대상으로 orders와 order_items를 연결합니다.
--     2. 주문별로 SUM(line_total)을 먼저 계산하는 CTE를 만들면
--        주문상품 수 때문에 Frequency가 부풀어 오르는 것을 막을 수 있습니다.
--     3. 주문별 집계 결과를 customer_id별로 묶어 RFM을 계산합니다.
--        - Recency: CURRENT_DATE - MAX(order_ts)::date
--        - Frequency: COUNT(*) 또는 COUNT(DISTINCT order_id)
--        - Monetary: SUM(주문별 금액)
--     4. 고객 이름이나 이메일도 필요하다면 customers를 customer_id로 연결합니다.
--     5. 구매 이력이 없는 고객까지 포함해야 하는지 생각해 보세요.
--        포함한다면 customers에서 시작해 LEFT JOIN하고 NULL 처리도 필요합니다.
--     6. 문제는 RFM 값 계산이 핵심입니다. 점수화나 고객 등급 분류는
--        별도 요구가 없다면 우선 원본 R/F/M 값까지만 조회해도 됩니다.
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS)
WITH orders_totals AS (
    SELECT 
        o.order_id,
        o.customer_id,
        o.order_ts,
        SUM(oi.line_total) AS order_amount
    FROM ecom.orders AS o
    JOIN ecom.order_items AS oi on o.order_id = oi.order_id
    WHERE o.order_status IN ('paid', 'shipped', 'delivered')
    GROUP BY o.order_id, o.customer_id, o.order_ts
)
SELECT 
    cust.customer_id, 
    cust.full_name,
    cust.email,
    CURRENT_DATE - MAX(order_ts)::date AS recency,
    COUNT(DISTINCT order_id) AS frequency,
    SUM(ot.order_amount) AS monetary
FROM orders_totals AS ot
JOIN ecom.customers AS cust ON ot.customer_id = cust.customer_id
GROUP BY cust.customer_id, cust.full_name, cust.email
ORDER BY monetary DESC;

