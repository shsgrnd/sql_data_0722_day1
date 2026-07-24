/*
 * 종합실습 4 - 실습 문제 Q6~Q11 (튜닝 전)
 *
 * 작업 환경 및 제출 항목
 * - Local PC에 설치한 PostgreSQL에서 실행합니다.
 * - 튜닝 대상 10개 문항 중 Q6~Q10의 튜닝 전 쿼리를 이 파일에 작성합니다.
 * - 각 문항별로 쿼리와 실행 결과가 함께 보이도록 화면을 캡처합니다.
 * - Q11은 10개 튜닝 문항과 별도의 안전 나눗셈 함수 작성 문제입니다.
 *
 * 작성 시 유의사항
 * - 요구사항에 필요한 컬럼만 조회합니다.
 * - DB 프로그래밍에 대한 주석을 작성합니다.
 * - 튜닝 후 쿼리는 total4_query_tuned.sql에 작성합니다.
 */

-- ============================================================
-- Q6. 첫 구매 후 30일 내 재구매율
--     [제출] 튜닝 전 쿼리 및 실행 결과 화면
--
--     [힌트]
--     1. 실제 판매 주문(paid, shipped, delivered)만 대상으로 합니다.
--     2. 고객별 첫 구매 시각은 MIN(order_ts)로 구합니다.
--        customer_id별로 GROUP BY한 CTE를 먼저 만들어 보세요.
--     3. 첫 구매 이후의 주문 중 다음 범위에 속하는 주문이 있는지 확인합니다.
--        - 재구매 시각 > 첫 구매 시각
--        - 재구매 시각 <= 첫 구매 시각 + INTERVAL '30 days'
--     4. EXISTS를 이용하면 한 고객이 기간 안에 여러 번 재구매해도
--        재구매 고객 한 명으로만 계산할 수 있습니다.
--     5. 재구매율의 계산식은 다음과 같습니다.
--        30일 내 재구매 고객 수 / 첫 구매 고객 수
--     6. 정수끼리 나누면 소수 부분이 사라질 수 있으므로 분자 또는 분모를
--        numeric으로 변환하고, 0으로 나누지 않도록 NULLIF를 사용해 보세요.
--     7. 엄밀한 분석에서는 첫 구매 후 아직 30일이 지나지 않은 고객을
--        분모에서 제외할지 검토합니다. 포함 여부를 주석으로 명시하세요.
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS)
WITH first_purchases AS (
    SELECT 
        o.customer_id,
        MIN(o.order_ts) AS first_order_ts
    FROM ecom.orders AS O
    WHERE o.order_status IN ('paid', 'shipped', 'delivered')
    GROUP BY o.customer_id
    HAVING MIN(o.order_ts) <= CURRENT_TIMESTAMP - INTERVAL '30 days'
),
repurchase_flags AS (
    SELECT 
        fp.customer_id,
        fp.first_order_ts, 
        EXISTS (
            SELECT 1
            FROM ecom.orders AS next_o
            WHERE next_o.customer_id = fp.customer_id
              AND next_o.order_status IN ('paid', 'shipped', 'delivered')
              AND next_o.order_ts > fp.first_order_ts
              AND next_o.order_ts <= fp.first_order_ts + INTERVAL '30 days'
        ) AS repurchased_within_30d
        FROM first_purchases AS fp
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
    ) AS repurchased_rate_pct
FROM repurchase_flags;

-- ============================================================
-- Q7. 재고가 임계치보다 낮은 상품 찾기
--     - 곧 품절될 위험이 있는 상품을 조회합니다.
--     - 재고 수량과 상품별 reorder_point를 비교합니다.
--     [제출] 튜닝 전 쿼리 및 실행 결과 화면
--
--     [힌트]
--     1. 재고 수량과 임계치는 ecom.inventory의 다음 컬럼에 있습니다.
--        - qty_on_hand: 현재 재고
--        - reorder_point: 재주문 임계치
--     2. 상품명과 SKU를 보려면 inventory와 products를 product_id로 연결합니다.
--     3. 문제의 "임계치보다 낮은" 조건은 qty_on_hand < reorder_point입니다.
--        <=를 사용하면 임계치와 같은 상품까지 포함되므로 문구에 주의하세요.
--     4. 부족 수량을 함께 표시하려면 reorder_point - qty_on_hand를 계산합니다.
--     5. 위험도가 높은 상품부터 보려면 현재 재고의 오름차순 또는
--        부족 수량의 내림차순으로 정렬해 보세요.
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    p.product_id,
    p.product_name,
    inven.qty_on_hand, 
    inven.reorder_point,
    inven.reorder_point - inven.qty_on_hand AS need_qty
FROM ecom.products AS p 
JOIN ecom.inventory AS inven ON p.product_id = inven.product_id
WHERE inven.qty_on_hand < inven.reorder_point
ORDER BY need_qty DESC;

-- ============================================================
-- Q8. 리뷰 효자상품 찾기
--     - 평균 평점 4.5 이상
--     - 리뷰 수 50개 이상
--     - 리뷰가 많고 평가도 좋은 상품을 조회합니다.
--     [제출] 튜닝 전 쿼리 및 실행 결과 화면
--
--     [힌트]
--     1. ecom.reviews와 ecom.products를 product_id로 연결합니다.
--     2. 제품별로 GROUP BY한 뒤 다음 두 값을 계산합니다.
--        - 평균 평점: AVG(rating)
--        - 리뷰 수: COUNT(*)
--     3. 집계 결과에 조건을 적용하므로 WHERE가 아니라 HAVING을 사용합니다.
--        - AVG(rating) >= 4.5
--        - COUNT(*) >= 50
--     4. 평균 평점을 먼저 내림차순 정렬하고, 같은 평점이면 리뷰 수를
--        내림차순 정렬하면 평가가 좋고 리뷰도 많은 상품을 먼저 볼 수 있습니다.
--     5. 표시용으로만 평균을 반올림하려면 ROUND를 사용할 수 있지만,
--        HAVING 조건은 반올림 전 실제 평균을 기준으로 적용하는 것이 안전합니다.
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.product_id,
    p.product_name,
    ROUND(AVG(rev.rating), 2) AS rating,
    COUNT(*) AS reviews_cnt
FROM ecom.products AS p
JOIN ecom.reviews AS rev on p.product_id = rev.product_id
GROUP BY p.product_id, p.product_name
HAVING AVG(rev.rating) >= 4.5
   AND COUNT(*) >= 50
ORDER BY rating DESC, reviews_cnt DESC;

-- ============================================================
-- Q9. 쿠폰 사용 영향 분석
--     - 쿠폰을 사용한 주문과 사용하지 않은 주문의
--       평균 주문 금액을 비교합니다.
--     [제출] 튜닝 전 쿼리 및 실행 결과 화면
--
--     [힌트]
--     1. 실제 판매 주문만 대상으로 orders와 order_items를 연결합니다.
--     2. 먼저 주문별 SUM(line_total)을 구하는 CTE를 만듭니다.
--        이때 CTE에 order_id와 coupon_code도 포함하세요.
--     3. 쿠폰 사용 여부는 coupon_code가 NULL인지 아닌지로 나눌 수 있습니다.
--        CASE WHEN coupon_code IS NOT NULL THEN 'coupon_used'
--             ELSE 'no_coupon' END
--     4. 주문별 집계 결과를 쿠폰 사용 여부로 GROUP BY한 뒤
--        AVG(주문별 금액)을 계산합니다.
--     5. order_items를 바로 평균 내면 "주문당 평균"이 아니라
--        "주문상품 행당 평균"이 되므로 주문별 선집계가 중요합니다.
--     6. 비교를 쉽게 하려면 그룹별 주문 수 COUNT(*)도 함께 조회해 보세요.
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS)
WITH orders_totals AS (
    SELECT 
        o.order_id,
        CASE 
            WHEN coupon_code IS NOT NULL THEN 'coupon_used'
            ELSE 'no_coupon' 
        END AS coupon_used,
        SUM(oi.line_total) AS order_amount
    FROM ecom.orders AS o
    JOIN ecom.order_items AS oi on o.order_id = oi.order_id
    WHERE o.order_status IN ('paid', 'shipped', 'delivered')
    GROUP BY o.order_id, o.coupon_code
)
SELECT 
    coupon_used,
    AVG(order_amount) AS avg_amount,
    COUNT(*) AS order_count
FROM orders_totals
GROUP BY coupon_used
ORDER BY coupon_used;

-- ============================================================
-- Q10. 상위 1% 고객의 최근 60일 매출
--      [제출] 튜닝 전 쿼리 및 실행 결과 화면
--
--      [힌트]
--      1. 실제 판매 주문 중 최근 60일 주문만 대상으로 합니다.
--         order_ts >= CURRENT_TIMESTAMP - INTERVAL '60 days'
--      2. 먼저 주문별 SUM(line_total)을 계산한 뒤 고객별로 다시 합산하면
--         고객별 최근 60일 매출을 정확하게 구할 수 있습니다.
--      3. 고객별 매출을 내림차순 기준으로 다음 중 하나를 적용해 보세요.
--         - CUME_DIST() OVER (ORDER BY 고객매출 DESC)
--         - NTILE(100) OVER (ORDER BY 고객매출 DESC)
--      4. CUME_DIST를 사용하면 누적 비율이 0.01 이하인 고객,
--         NTILE(100)을 사용하면 첫 번째 구간인 고객이 상위 1%입니다.
--      5. 윈도우 함수 결과는 같은 SELECT의 WHERE에서 바로 필터링할 수 없으므로
--         순위/비율 계산 결과를 CTE 또는 서브쿼리로 한 번 더 감싸세요.
--      6. 고객 이름과 이메일이 필요하면 마지막에 customers를
--         customer_id로 연결합니다.
--      7. 동점 고객 처리 방식과 최근 60일 구매가 없는 고객을 모집단에
--         포함할지에 따라 결과가 달라질 수 있으므로 선택 기준을 주석으로 남기세요.
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS)
WITH customer_sales AS (
    SELECT 
        o.customer_id,
        SUM(oi.line_total) AS sales_60d
    FROM ecom.orders AS o
    JOIN ecom.order_items AS oi on o.order_id = oi.order_id
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
JOIN ecom.customers AS cust ON cust.customer_id = rc.customer_id
WHERE rc.sales_group = 1
ORDER BY rc.sales_60d DESC;

-- ============================================================
-- Q11. 0으로 나누어도 에러가 발생하지 않는 나눗셈 함수
--      - 0으로 나누는 상황을 방지하여 평균을 안전하게 계산합니다.
--      [작성] PostgreSQL 함수 생성 스크립트 및 동작 확인
--
--      [힌트]
--      1. CREATE OR REPLACE FUNCTION으로 ecom 스키마에 함수를 만듭니다.
--      2. 분자와 분모 매개변수는 numeric, 반환형도 numeric으로 선언합니다.
--      3. 분모가 0 또는 NULL이면 NULL을 반환하고, 그렇지 않으면
--         분자 / 분모를 반환하도록 CASE 또는 NULLIF를 사용합니다.
--      4. SQL 한 문장으로 작성할 수 있으므로 LANGUAGE sql을 사용할 수 있습니다.
--         같은 입력에 항상 같은 결과를 반환하므로 IMMUTABLE 지정도 검토하세요.
--      5. 함수 작성 후 다음 경우를 각각 실행해 동작을 확인합니다.
--         - 정상적인 나눗셈
--         - 분모가 0인 경우
--         - 분모가 NULL인 경우
--      6. 함수 생성문의 본문은 $$ ... $$로 감싸면 따옴표 처리가 편리합니다.
-- ============================================================
-- 분모가 0 또는 NULL이면 NULL을 반환하여 나눗셈 오류를 방지합니다.
CREATE OR REPLACE FUNCTION ecom.safe_div(
    n NUMERIC,
    d NUMERIC
)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN d IS NULL OR d = 0 THEN NULL
        ELSE n / d
    END
$$;

-- 한 화면에서 확인
SELECT
    ecom.safe_div(10, 2)    AS normal_result,
    ecom.safe_div(10, 0)    AS zero_denominator,
    ecom.safe_div(10, NULL) AS null_denominator;
