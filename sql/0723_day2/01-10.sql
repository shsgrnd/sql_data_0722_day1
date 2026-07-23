/*
===============================================================================
 PostgreSQL 종합 실습
 문항 범위: 1번 ~ 10번
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
 1번
-------------------------------------------------------------------------------
학생과 수강을 INNER JOIN하여 수강 기록이 존재하는 학생의 과목과 성적을
조회한다.
*/
SELECT s.student_id, s.name, e.course, e.grade
FROM student s
INNER JOIN enroll e on s.student_id = e.student_id
ORDER BY s.student_id
LIMIT 5;

/*
-------------------------------------------------------------------------------
 2번
-------------------------------------------------------------------------------
모든 학생을 기준으로 수강 정보를 연결한다.

- 수강한 과목이 없는 학생도 결과에 포함한다.
- 과목이 없는 경우 과목 관련 정보가 NULL로 표시되도록 한다.
*/
SELECT s.student_id, s.name, e.course, e.grade
FROM student s
LEFT JOIN enroll e on s.student_id = e.student_id
ORDER BY s.student_id
LIMIT 5;


/*
-------------------------------------------------------------------------------
 3번
-------------------------------------------------------------------------------
수강 정보를 기준으로 조회한다.

- 대응하는 학생이 없는 고아 수강 데이터도 결과에 포함한다.
- 학생이 없으면 학생 정보가 NULL로 표시되도록 한다.
*/
SELECT 
    e.student_id AS enroll_student_id,
    s.student_id AS student_id,
    s.name,
    e.course,
    e.grade
FROM enroll e
LEFT JOIN student s on e.student_id = s.student_id
ORDER BY e.course, e.grade
LIMIT 5;


/*
-------------------------------------------------------------------------------
 4번
-------------------------------------------------------------------------------
학생 데이터와 수강 데이터를 양쪽 모두 포함하여 조회한다.

- 학생만 존재하는 데이터도 포함한다.
- 수강 정보만 존재하는 데이터도 포함한다.
*/
SELECT 
    e.student_id AS enroll_student_id,
    s.student_id AS student_id,
    s.name,
    e.course,
    e.grade
FROM student s
FULL OUTER JOIN enroll e on e.student_id = s.student_id
ORDER BY  COALESCE(s.student_id, e.student_id), e.course
LIMIT 5;


/*
-------------------------------------------------------------------------------
 5번
-------------------------------------------------------------------------------
한 번도 수강하지 않은 학생 목록을 조회한다.
*/
SELECT s.student_id, s.name
FROM student s
LEFT JOIN enroll e ON e.student_id = s.student_id
WHERE e.student_id IS NULL
ORDER BY s.student_id
LIMIT 5;

/*
-------------------------------------------------------------------------------
 6번
-------------------------------------------------------------------------------
한 과목 이상 수강한 학생 목록을 조회한다.

- 동일 학생이 여러 수강 기록을 가지더라도 학생은 중복되지 않도록 한다.
*/

SELECT DISTINCT s.student_id, s.name
FROM student s
INNER JOIN enroll e ON e.student_id = s.student_id
ORDER BY s.student_id
LIMIT 5;


/*
-------------------------------------------------------------------------------
 7번
-------------------------------------------------------------------------------
고객별 주문 건수와 총 주문 금액을 조회한다.
*/
SELECT cus.customer_id, cus.customer_name ,COUNT(o.order_id) AS order_count, SUM(o.amount) AS total_amount
FROM customers cus
INNER JOIN orders o on cus.customer_id = o.customer_id
GROUP BY cus.customer_id, cus.customer_name
ORDER BY cus.customer_id
LIMIT 5;

/*
-------------------------------------------------------------------------------
 8번
-------------------------------------------------------------------------------
총 주문 금액이 높은 고객 상위 10명과 해당 금액을 조회한다.
*/

SELECT cus.customer_id, cus.customer_name , SUM(o.amount) AS total_amount
FROM customers cus
INNER JOIN orders o on cus.customer_id = o.customer_id
GROUP BY cus.customer_id, cus.customer_name
ORDER BY total_amount DESC, cus.customer_id
LIMIT 10;

/*
-------------------------------------------------------------------------------
 9번
-------------------------------------------------------------------------------
모든 직원과 각 직원의 매니저 이름을 조회한다.

- CEO처럼 매니저가 없는 직원도 결과에 포함한다.
*/
SELECT e.emp_id, e.name AS employee_name, m.name AS manager_name
FROM emp e
LEFT JOIN emp m on e.manager_id = m.emp_id
ORDER BY e.emp_id
LIMIT 5;


/*
-------------------------------------------------------------------------------
 10번
-------------------------------------------------------------------------------
모든 학생을 기준으로 과목별 수강 분포를 확인한다.

- LEFT JOIN과 집계를 사용한다.
- 수강 기록이 없는 학생도 결과 분석에 포함한다.
*/
SELECT e.course ,COUNT(s.student_id) AS student_count
FROM student s
LEFT JOIN enroll e on s.student_id = e.student_id
GROUP BY e.course
ORDER BY e.course NULLS FIRST
LIMIT 5;


