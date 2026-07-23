/*
===============================================================================
 PostgreSQL 종합 실습
 문항 범위: 11번 ~ 13번
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
 11번
-------------------------------------------------------------------------------
DB 과목을 듣지 않은 모든 학생을 나열한다.
*/
SELECT s.student_id, s.name
FROM student s 
LEFT JOIN enroll e 
    ON s.student_id = e.student_id
    AND e.course = 'DB'
WHERE e.student_id IS NULL
ORDER BY s.student_id
LIMIT 5;

/*
-------------------------------------------------------------------------------
 12번
-------------------------------------------------------------------------------
과목별로 매니저가 운영 책임을 가진다고 가정하여 리포트를 작성한다.

요구사항:

- emp 테이블에서 이름이 Mgr_로 시작하는 매니저를 사용한다.
- 매니저와 과목을 임의로 매핑하는 테이블을 만든다.
- 매핑 테이블 이름은 course_owner로 한다.
- course_owner의 주요 컬럼은 다음과 같다.
  - course
  - manager_id
- 과목별 수강 인원과 책임 매니저 이름을 조회하는 리포트를 작성한다.
*/
CREATE TABLE course_owner (
  course VARCHAR(50), 
  manager_id INT
);

INSERT INTO course_owner (course, manager_id)
VALUES 
    ('DB', 2),
    ('AI', 3),
    ('ML', 4),
    ('Course_1', 5),
    ('Course_2', 6),
    ('Course_3', 7),
    ('Course_4', 8),
    ('Course_5', 9),
    ('Course_6', 10),
    ('Course_7', 11),
    ('Course_8', 2),
    ('Course_9', 3),
    ('Course_10', 4),
    ('Course_11', 5),
    ('Course_12', 6),
    ('Course_13', 7),
    ('Course_14', 8),
    ('Course_15', 9),
    ('Course_16', 10),
    ('Course_17', 11),
    ('Course_18', 2),
    ('Course_19', 3),
    ('Course_20', 4);


SELECT co.course, 
    COUNT(DISTINCT e.student_id) AS student_count,
    m.name AS manager_name
FROM course_owner co 
LEFT JOIN enroll e ON co.course = e.course
INNER JOIN emp m ON co.manager_id = m.emp_id
GROUP BY co.course, m.name
ORDER BY co.course
LIMIT 5;





/*
-------------------------------------------------------------------------------
 13번
-------------------------------------------------------------------------------
학생과 과목의 전체 조합을 만들어 학생별 과목 추천 후보를 생성한다.

- 학생과 과목의 모든 조합을 만든다.
- 샘플 결과는 100건만 조회한다.
*/
SELECT
    s.student_id,
    s.name,
    c.course
FROM student s
CROSS JOIN (
    SELECT DISTINCT course
    FROM enroll
) c
ORDER BY s.student_id, c.course
LIMIT 100;
