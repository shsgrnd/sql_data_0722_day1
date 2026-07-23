/*
===============================================================================
 PostgreSQL 종합 실습
 문항 범위: 14번 ~ 20번
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
 14번
-------------------------------------------------------------------------------
스칼라 서브쿼리, 즉 SELECT 절의 서브쿼리를 사용하여 학생과 소속 학과를
함께 조회한다.
*/
SELECT
    s.student_id,
    s.name,
    (
        SELECT s2.major
        FROM student s2
        WHERE s2.student_id = s.student_id
    ) AS major
FROM student s
ORDER BY s.student_id
LIMIT 5;

/*
-------------------------------------------------------------------------------
 15번
-------------------------------------------------------------------------------
전체 학생의 평균 GPA보다 GPA가 높은 학생을 조회한다.

- WHERE 절의 서브쿼리를 사용한다.
*/
SELECT s.student_id, s.name, s.gpa
FROM student s
WHERE s.gpa > (
    SELECT AVG(s2.gpa)
    FROM student s2
)
ORDER BY s.student_id
LIMIT 5;

/*
-------------------------------------------------------------------------------
 16번
-------------------------------------------------------------------------------
각 학생의 GPA를 해당 학생이 속한 학과의 평균 GPA와 비교한다.

- 자신의 학과 평균 GPA보다 높은 학생을 조회한다.
- 상관 서브쿼리인 Correlated subquery를 사용한다.
*/
SELECT s.student_id, s.name, s.major, s.gpa
FROM student s
WHERE s.gpa > (
    SELECT AVG(s2.gpa)
    FROM student s2
    WHERE s2.major = s.major
)
ORDER BY s.student_id
LIMIT 5;

/*
-------------------------------------------------------------------------------
 17번
-------------------------------------------------------------------------------
수강 기록이 존재하는 학생만 조회한다.
*/
SELECT s.student_id, s.name
FROM student s
WHERE EXISTS (
    SELECT 1
    FROM enroll e
    WHERE e.student_id = s.student_id
)
ORDER BY s.student_id
LIMIT 5;

/*
-------------------------------------------------------------------------------
 18번
-------------------------------------------------------------------------------
한 번도 수강하지 않은 학생을 조회한다.
*/
SELECT s.student_id, s.name
FROM student s
WHERE NOT EXISTS (
    SELECT 1
    FROM enroll e
    WHERE e.student_id = s.student_id
)
ORDER BY s.student_id
LIMIT 5;

/*
-------------------------------------------------------------------------------
 19번
-------------------------------------------------------------------------------
HR 학과 학생 일부와 다른 학과 학생 일부를 비교하는 데모 쿼리를 작성한다.
*/
SELECT s.student_id, s.name, s.major, s.gpa
FROM student s
WHERE s.major = 'HR'
ORDER BY s.student_id
LIMIT 5;

SELECT s.student_id, s.name, s.major, s.gpa
FROM student s
WHERE s.major <> 'HR'
ORDER BY s.student_id
LIMIT 5;

/*
-------------------------------------------------------------------------------
 20번
-------------------------------------------------------------------------------
다음 조건 중 하나를 만족하는 학생 목록을 조회한다.

- CS 학과 학생
- DB 과목을 수강한 학생
*/
SELECT s.student_id, s.name, s.major
FROM student s
WHERE s.major = 'CS'

UNION

SELECT s.student_id, s.name, s.major
FROM student s
INNER JOIN enroll e ON e.student_id = s.student_id
WHERE e.course = 'DB'

ORDER BY student_id
LIMIT 5;
