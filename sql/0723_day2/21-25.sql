/*
===============================================================================
 PostgreSQL 종합 실습
 문항 범위: 21번 ~ 25번
===============================================================================

[공통 데이터 배경]

1. 학사 시스템: student, enroll

   - 규칙상 학생별 수강 건수는 0~2건이다.
   - student_id % 3 = 0인 학생은 수강 0건이다.
     약 333명의 학생이 수강 기록을 가지지 않는다.
   - student_id % 3 = 1인 학생은 수강 1건이다.
     약 334명의 학생이 해당한다.
   - student_id % 3 = 2인 학생은 수강 2건이다.
     약 333명의 학생이 해당한다.
   - enroll에만 존재하고 student에는 대응하는 학생이 없는
     고아 수강 데이터 2건이 포함되어 있다.
   - 해당 student_id는 1001과 1010이다.

2. 캠퍼스 스토어: customers, orders

   - 고객 1명당 정확히 6건의 주문이 존재한다.

3. 조직도: emp

   - CEO 1명, 매니저 10명, 직원 300명으로 구성된다.
   - 각 직원은 매니저 10명 중 1명에게 배정된다.

[DBMS 참고]

- PostgreSQL/MySQL: LIMIT 5
- SQL Server: TOP(5)
*/


/*
-------------------------------------------------------------------------------
 21번
-------------------------------------------------------------------------------
student 테이블에는 학과 major와 GPA가 있다.

학과별 GPA 구간별 인원을 집계하고, 소계와 총계를 한 번의 쿼리로 출력한다.

요구사항:

- GPA 구간을 나타내는 파생 컬럼 gpa_tier를 추가한다.
- GPA 구간은 다음과 같이 분류한다.
  - 3.0 미만
  - 3.0 이상 3.5 이하
  - 3.5 초과
- GROUP BY ROLLUP(major, gpa_tier)을 이용해 다음 결과를 함께 조회한다.
  - 학과별 GPA 구간 집계
  - 학과별 소계
  - 전체 총계
- GROUPING(major) 함수를 사용한다.
- 소계 또는 총계 행의 학과 표시에는 전체 라벨을 사용한다.
- 결과는 major, gpa_tier 순으로 정렬한다.
- 소계 행은 각 학과 결과의 하단에 표시한다.
*/
WITH student_tier AS (
  SELECT 
      major, 
      CASE
        WHEN gpa < 3.0 THEN '3.0 미만'
        WHEN gpa <= 3.5 THEN '3.0 이상 3.5 이하'
        ELSE '3.5 초과'
      END AS gpa_tier
  FROM student
)
SELECT 
  CASE
    WHEN GROUPING(st.major) = 1
    OR GROUPING(st.gpa_tier) = 1
    THEN '전체'
    ELSE st.major
  END AS major,
  CASE
    WHEN GROUPING(st.major) = 1 THEN '전체 총계'
    WHEN GROUPING(st.gpa_tier) = 1 THEN '학과 소계'
    ELSE st.gpa_tier
  END AS gpa_tier,
  COUNT(*) AS student_count
FROM student_tier st
GROUP BY ROLLUP(st.major, st.gpa_tier)
ORDER BY
  GROUPING(st.major),
  st.major,
  GROUPING(st.gpa_tier),
  st.gpa_tier;

/*
-------------------------------------------------------------------------------
 22번
-------------------------------------------------------------------------------
emp 테이블의 조직 계층을 재귀적으로 조회한다.

데이터 구조:

- CEO는 manager_id = NULL이다.
- 매니저는 10명이다.
- 개발자는 300명이다.
- CEO → 매니저 → 개발자의 3단계 계층 구조이다.

요구사항:

- WITH RECURSIVE를 사용한다.
- CEO에서 시작하는 조직 트리를 탐색한다.
- 모든 직원의 계층 경로를 출력한다.
- 각 직원의 계층 깊이를 출력한다.
- depth 컬럼을 포함한다.
  - CEO의 depth는 0이다.
- path 컬럼을 포함한다.
- 경로 표현 예시는 다음과 같다.
  - CEO > Mgr_2 > Dev_15
- 매니저별 직속 부하 직원 수를 집계하는 별도 쿼리도 작성한다.
- 직속 부하 직원 수의 컬럼명은 direct_reports로 한다.
*/


WITH RECURSIVE org_tree AS (
    SELECT
        emp_id,
        name,
        manager_id,
        0 AS depth,
        name::TEXT AS path
    FROM emp
    WHERE manager_id IS NULL

    UNION ALL

    SELECT
        e.emp_id,
        e.name,
        e.manager_id,
        ot.depth + 1,
        ot.path || ' > ' || e.name
    FROM emp e
    INNER JOIN org_tree ot ON e.manager_id = ot.emp_id
)
SELECT emp_id, name, depth, path
FROM org_tree
ORDER BY path;

SELECT
    m.emp_id AS manager_id,
    m.name AS manager_name,
    COUNT(e.emp_id) AS direct_reports
FROM emp m
LEFT JOIN emp e ON e.manager_id = m.emp_id
WHERE m.name LIKE 'Mgr\_%' ESCAPE '\'
GROUP BY m.emp_id, m.name
ORDER BY m.emp_id;




/*
-------------------------------------------------------------------------------
 23번
-------------------------------------------------------------------------------
각 학과 major별로 GPA가 높은 순서대로 순위를 매기고 상위 3명씩 추출한다.

- Window Function을 사용한다.
- 서브쿼리 방식과 CTE 방식 모두 작성한다.
- 학과 내 순위를 계산한다.
- 정렬 기준은 GPA 내림차순이다.
- GPA가 동일하면 student_id 오름차순을 2차 기준으로 사용한다.
- 다음 Window Function을 함께 계산하여 동점 처리 방식의 차이를 비교한다.
  - ROW_NUMBER()
  - RANK()
  - DENSE_RANK()
- 결과에 학과별 전체 학생 수를 추가한다.
- 전체 학생 수 컬럼명은 total_in_major로 한다.
- 학과별 전체 학생 수는 COUNT() Window Function으로 계산한다.
*/


-- 서브쿼리 방식
-- ROW_NUMBER()는 student_id로 동점 순서를 확정하고,
-- RANK()와 DENSE_RANK()는 GPA만 기준으로 계산해 동점 처리 차이를 비교한다.
SELECT
    student_id,
    name,
    major,
    gpa,
    row_num,
    rank_num,
    dense_rank_num,
    total_in_major
FROM (
    SELECT
        s.student_id,
        s.name,
        s.major,
        s.gpa,
        ROW_NUMBER() OVER (
            PARTITION BY s.major
            ORDER BY s.gpa DESC, s.student_id
        ) AS row_num,
        RANK() OVER (
            PARTITION BY s.major
            ORDER BY s.gpa DESC
        ) AS rank_num,
        DENSE_RANK() OVER (
            PARTITION BY s.major
            ORDER BY s.gpa DESC
        ) AS dense_rank_num,
        COUNT(*) OVER (
            PARTITION BY s.major
        ) AS total_in_major
    FROM student s
) ranked
WHERE row_num <= 3
ORDER BY major, row_num;

-- CTE 방식
-- ROW_NUMBER()는 student_id로 동점 순서를 확정하고,
-- RANK()와 DENSE_RANK()는 GPA만 기준으로 계산해 동점 처리 차이를 비교한다.
WITH ranked_students AS (
    SELECT
        s.student_id,
        s.name,
        s.major,
        s.gpa,
        ROW_NUMBER() OVER (
            PARTITION BY s.major
            ORDER BY s.gpa DESC, s.student_id
        ) AS row_num,
        RANK() OVER (
            PARTITION BY s.major
            ORDER BY s.gpa DESC
        ) AS rank_num,
        DENSE_RANK() OVER (
            PARTITION BY s.major
            ORDER BY s.gpa DESC
        ) AS dense_rank_num,
        COUNT(*) OVER (
            PARTITION BY s.major
        ) AS total_in_major
    FROM student s
)
SELECT
    student_id,
    name,
    major,
    gpa,
    row_num,
    rank_num,
    dense_rank_num,
    total_in_major
FROM ranked_students
WHERE row_num <= 3
ORDER BY major, row_num;




/*
-------------------------------------------------------------------------------
 24번
-------------------------------------------------------------------------------
enroll 테이블을 학생별, 과목별 순서로 정렬하고 이전 수강 과목 대비 성적
변화를 계산한다.

요구사항:

- grade를 숫자 점수로 변환하는 CASE 식을 작성한다.
- 성적 변환 기준은 다음과 같다.
  - A = 4
  - B = 3
  - C = 2
  - D = 1
- 변환된 숫자 점수를 현재 점수로 사용한다.
- 학생별로 student_id를 기준으로 파티션을 나눈다.
- 과목 순서는 course를 기준으로 한다.
- LAG()를 이용해 이전 과목의 점수를 가져온다.
- 현재 점수와 이전 점수의 차이를 diff 컬럼으로 추가한다.
- 성적 변화 상태를 텍스트로 표시한다.
  - 상승
  - 유지
  - 하락
- 학생별 최고점과 최저점의 차이를 계산한다.
- 해당 컬럼명은 score_range로 한다.
- 최고점과 최저점 계산에는 Window Function을 사용한다.
*/


WITH scored AS (
    SELECT
        student_id,
        course,
        grade,
        CASE grade
            WHEN 'A' THEN 4
            WHEN 'B' THEN 3
            WHEN 'C' THEN 2
            WHEN 'D' THEN 1
        END AS current_score
    FROM enroll
),
grade_windows AS (
    SELECT
        student_id,
        course,
        grade,
        current_score,
        LAG(current_score) OVER (
            PARTITION BY student_id
            ORDER BY course
        ) AS previous_score,
        MAX(current_score) OVER (
            PARTITION BY student_id
        ) - MIN(current_score) OVER (
            PARTITION BY student_id
        ) AS score_range
    FROM scored
)
SELECT
    student_id,
    course,
    grade,
    current_score,
    previous_score,
    current_score - previous_score AS diff,
    CASE
        WHEN previous_score IS NULL THEN NULL
        WHEN current_score > previous_score THEN '상승'
        WHEN current_score = previous_score THEN '유지'
        ELSE '하락'
    END AS change_status,
    score_range
FROM grade_windows
ORDER BY student_id, course;




/*
-------------------------------------------------------------------------------
 25번
-------------------------------------------------------------------------------
orders 테이블의 주문을 order_id 순으로 정렬하여 누적 주문 금액과 3개 주문
이동평균을 계산한다.

- ROWS BETWEEN을 사용한다.
- SUM(amount) OVER (
    ORDER BY order_id
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  )로 누적합을 계산한다.
- AVG(amount) OVER (
    ORDER BY order_id
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  )로 3개 이동평균을 계산한다.
- customer_id별로 PARTITION을 나눠 고객별 누적 구매 금액도 함께 계산한다.
- 누적합이 전체 합의 50%를 처음 초과하는 첫 번째 order_id를 찾는 쿼리를
  작성한다.
*/


SELECT
    order_id,
    customer_id,
    amount,
    SUM(amount) OVER (
        ORDER BY order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_amount,
    AVG(amount) OVER (
        ORDER BY order_id
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_average_3,
    SUM(amount) OVER (
        PARTITION BY customer_id
        ORDER BY order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS customer_cumulative_amount
FROM orders
ORDER BY order_id
LIMIT 5;

WITH order_running AS (
    SELECT
        order_id,
        SUM(amount) OVER (
            ORDER BY order_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_amount,
        SUM(amount) OVER () AS total_amount
    FROM orders
)
SELECT order_id
FROM order_running
WHERE cumulative_amount > total_amount * 0.5
ORDER BY order_id
LIMIT 1;
