/*
===============================================================================
 종합실습 3 - HR DB 느린 쿼리 최적화
 대상 DBMS: PostgreSQL 11+

 실행 전 준비
   1. scripts/day3의 환경설정 SQL에서 PART 0을 먼저 실행한다.
   2. 이 파일은 위에서 아래로 내려가며 "한 문장씩" 실행한다.
   3. 각 문항의 튜닝 전/후 EXPLAIN ANALYZE 결과를 비교한다.

 EXPLAIN ANALYZE를 읽을 때 볼 항목
   - Seq Scan / Index Scan / Index Only Scan / Bitmap Heap Scan
   - Planning Time, Execution Time
   - cost: 실행 전에 옵티마이저가 예상한 비용
   - rows: 예상 행 수, actual rows: 실제 행 수
   - Buffers의 shared hit/read: 메모리 적중/디스크 읽기 블록 수

 주의
   - EXPLAIN ANALYZE는 쿼리를 실제로 실행한다.
   - 캐시 영향을 줄이기 위해 같은 "튜닝 전" 쿼리를 두 번 실행하고,
     두 번째 결과를 튜닝 후 결과와 비교하는 것이 좋다.
===============================================================================
*/

SET search_path = hr, public;


/*
-------------------------------------------------------------------------------
 0. 실습 초기화
-------------------------------------------------------------------------------
환경설정 파일의 PART 1까지 이미 실행했더라도 튜닝 전 상태에서 다시 시작할 수 있도록
실습용 인덱스를 제거한다. PRIMARY KEY와 UNIQUE(email) 인덱스는 제거하지 않는다.
*/
DROP INDEX IF EXISTS hr.idx_employees_lower_email;
DROP INDEX IF EXISTS hr.idx_employees_rev_email;
DROP INDEX IF EXISTS hr.idx_emp_hire_status_salary;
DROP INDEX IF EXISTS hr.idx_emp_department_id;
DROP INDEX IF EXISTS hr.idx_emp_job_id;

DROP INDEX IF EXISTS hr.idx_employees_reverse_email_pattern;
DROP INDEX IF EXISTS hr.idx_employees_recent_active_salary;
DROP INDEX IF EXISTS hr.idx_employees_department_id;
DROP INDEX IF EXISTS hr.idx_employees_job_id;

-- 테이블 통계를 최신화해야 옵티마이저가 합리적인 실행 계획을 선택할 수 있다.
ANALYZE hr.employees;

-- 환경설정 결과 확인: 약 50,000건이면 정상이다.
SELECT COUNT(*) AS employee_count
FROM hr.employees;


/*
===============================================================================
 1번. 실행 계획 맛보기 - 사번(employee_id)이 100인 직원 검색
===============================================================================
employees.employee_id는 PRIMARY KEY이므로 별도 인덱스를 만들지 않아도
PK용 B-tree 인덱스가 이미 존재한다. 실행 계획에서 Seq Scan이 아닌
Index Scan이 선택되는지 확인한다.
*/
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.email,
    e.hire_date,
    e.salary,
    e.department_id,
    e.job_id,
    e.status
FROM hr.employees AS e
WHERE e.employee_id = 100;


/*
===============================================================================
 2번. lower(email)을 사용한 이메일 검색 튜닝
      검색값: user1234@corp.com
===============================================================================
email에는 UNIQUE 인덱스가 있지만, 조건식이 lower(email)이므로 일반 email 인덱스와
식의 모양이 다르다. 따라서 튜닝 전에는 전체 테이블을 읽는 Seq Scan이 발생한다.

참고: 환경설정 데이터의 이메일 도메인은 무작위이므로 user1234의 도메인이 corp.com이
아닐 수도 있다. 조회 결과가 0건이어도 "실행 계획 비교" 실습에는 문제가 없다.
*/

-- [튜닝 전] 워밍업용 1회 실행
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    e.employee_id,
    e.email
FROM hr.employees AS e
WHERE lower(e.email) = 'user1234@corp.com';

-- [튜닝 전] 비교 기준으로 저장할 2회차 실행 결과
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    e.employee_id,
    e.email
FROM hr.employees AS e
WHERE lower(e.email) = 'user1234@corp.com';

/*
함수 기반 인덱스(expression index)를 만든다.
쿼리의 WHERE절 표현식 lower(email)과 인덱스 표현식이 같아야 인덱스를 사용할 수 있다.
*/
CREATE INDEX idx_employees_lower_email
    ON hr.employees (lower(email));

ANALYZE hr.employees;

-- [튜닝 후] Index Scan과 실행 시간/버퍼 사용량 변화를 확인한다.
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    e.employee_id,
    e.email
FROM hr.employees AS e
WHERE lower(e.email) = 'user1234@corp.com';


/*
===============================================================================
 3번. 선행 와일드카드 LIKE 검색 튜닝
      검색값: '%gmail.com'
===============================================================================
'%gmail.com'은 문자열 앞부분이 정해져 있지 않다. 일반 B-tree 인덱스는 왼쪽부터
정렬되므로 이 조건으로 검색 범위를 좁힐 수 없다.

해결 방법:
  1. email을 reverse()로 뒤집어 접미사를 접두사로 바꾼다.
  2. reverse(email)에 함수 기반 인덱스를 만든다.
  3. text_pattern_ops를 지정해 LIKE '고정문자열%' 패턴을 인덱스로 처리한다.

원래 조건: email          LIKE '%gmail.com'
변환 조건: reverse(email) LIKE 'moc.liamg@%'
*/

-- [튜닝 전] 워밍업용 1회 실행
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) AS gmail_employee_count
FROM hr.employees AS e
WHERE e.email LIKE '%gmail.com';

-- [튜닝 전] 비교 기준으로 저장할 2회차 실행 결과
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) AS gmail_employee_count
FROM hr.employees AS e
WHERE e.email LIKE '%gmail.com';

/*
text_pattern_ops는 로케일 설정과 관계없이 접두사 LIKE 검색에 B-tree를 활용하게 한다.
email은 NOT NULL이므로 reverse(email)도 NULL이 되지 않는다.
*/
CREATE INDEX idx_employees_reverse_email_pattern
    ON hr.employees (reverse(email) text_pattern_ops);

ANALYZE hr.employees;

-- [튜닝 후] 의미는 같지만 인덱스를 사용할 수 있도록 조건식을 뒤집었다.
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) AS gmail_employee_count
FROM hr.employees AS e
WHERE reverse(e.email) LIKE 'moc.liamg@%';


/*
===============================================================================
 4번. 최근 입사한 재직자 중 급여 상위 100명 조회 튜닝
===============================================================================
조건
  - 최근 365일 이내 입사
  - 재직 중(status = 'ACTIVE')
  - 급여 내림차순 상위 100명
  - 부서명과 직무명 포함

튜닝 핵심:
  - ORDER BY salary DESC 순서로 인덱스를 읽으면 별도 Sort를 줄일 수 있다.
  - ACTIVE 직원만 담는 partial index로 인덱스 크기를 줄인다.
  - 조회/조인에 필요한 컬럼을 INCLUDE하여 Index Only Scan 가능성을 높인다.

hire_date를 인덱스 첫 컬럼으로 두고 범위 조건을 적용하면 그 뒤의 salary 정렬 순서를
전체 결과에 그대로 이용하기 어렵다. 여기서는 LIMIT 100을 빠르게 만족시키기 위해
salary DESC를 키로 사용하고, 인덱스를 급여순으로 읽으며 hire_date를 필터링한다.
*/

-- [튜닝 전] 워밍업용 1회 실행
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    e.employee_id,
    e.hire_date,
    e.salary,
    d.department_name,
    j.job_title
FROM hr.employees AS e
JOIN hr.departments AS d
  ON d.department_id = e.department_id
JOIN hr.jobs AS j
  ON j.job_id = e.job_id
WHERE e.hire_date >= CURRENT_DATE - INTERVAL '365 days'
  AND e.status = 'ACTIVE'
ORDER BY e.salary DESC
LIMIT 100;

-- [튜닝 전] 비교 기준으로 저장할 2회차 실행 결과
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    e.employee_id,
    e.hire_date,
    e.salary,
    d.department_name,
    j.job_title
FROM hr.employees AS e
JOIN hr.departments AS d
  ON d.department_id = e.department_id
JOIN hr.jobs AS j
  ON j.job_id = e.job_id
WHERE e.hire_date >= CURRENT_DATE - INTERVAL '365 days'
  AND e.status = 'ACTIVE'
ORDER BY e.salary DESC
LIMIT 100;

CREATE INDEX idx_employees_recent_active_salary
    ON hr.employees (salary DESC)
    INCLUDE (employee_id, hire_date, department_id, job_id)
    WHERE status = 'ACTIVE';

ANALYZE hr.employees;

-- [튜닝 후] Sort 제거 여부, 읽은 행/버퍼 수, LIMIT까지 걸린 시간을 비교한다.
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    e.employee_id,
    e.hire_date,
    e.salary,
    d.department_name,
    j.job_title
FROM hr.employees AS e
JOIN hr.departments AS d
  ON d.department_id = e.department_id
JOIN hr.jobs AS j
  ON j.job_id = e.job_id
WHERE e.hire_date >= CURRENT_DATE - INTERVAL '365 days'
  AND e.status = 'ACTIVE'
ORDER BY e.salary DESC
LIMIT 100;


/*
===============================================================================
 5번. OR 조건 검색 튜닝
      조건: 부서코드 10 또는 직무코드 3, 4, 5
===============================================================================
서로 다른 컬럼의 OR 조건은 적절한 인덱스가 없으면 Seq Scan이 되기 쉽다.
department_id와 job_id에 각각 인덱스를 만들면 PostgreSQL이 각 인덱스 결과를
BitmapOr로 합치는 실행 계획을 선택할 수 있다.
*/

-- [튜닝 전] 워밍업용 1회 실행
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.department_id,
    e.job_id
FROM hr.employees AS e
WHERE e.department_id = 10
   OR e.job_id IN (3, 4, 5);

-- [튜닝 전] 비교 기준으로 저장할 2회차 실행 결과
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.department_id,
    e.job_id
FROM hr.employees AS e
WHERE e.department_id = 10
   OR e.job_id IN (3, 4, 5);

CREATE INDEX idx_employees_department_id
    ON hr.employees (department_id);

CREATE INDEX idx_employees_job_id
    ON hr.employees (job_id);

ANALYZE hr.employees;

-- [튜닝 후 1] 원래 OR 쿼리: Bitmap Index Scan 두 개와 BitmapOr 여부를 확인한다.
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.department_id,
    e.job_id
FROM hr.employees AS e
WHERE e.department_id = 10
   OR e.job_id IN (3, 4, 5);

/*
[튜닝 후 2] UNION ALL 재작성 방식

단순히 두 SELECT를 UNION ALL로 연결하면 department_id = 10이면서 job_id가
3, 4, 5 중 하나인 직원이 두 번 나온다. 두 번째 SELECT에서 department_id = 10을
제외하여 원래 OR 쿼리와 동일한 결과를 유지한다.

employees.department_id는 NOT NULL이므로 <> 10만으로 안전하게 중복을 제거할 수 있다.
*/
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.department_id,
    e.job_id
FROM hr.employees AS e
WHERE e.department_id = 10

UNION ALL

SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.department_id,
    e.job_id
FROM hr.employees AS e
WHERE e.job_id IN (3, 4, 5)
  AND e.department_id <> 10;


/*
-------------------------------------------------------------------------------
 5번 결과 동일성 검증 (선택 실행)
-------------------------------------------------------------------------------
EXCEPT를 양방향으로 수행한 결과가 0행이면 OR 쿼리와 UNION ALL 재작성 쿼리가 같다.
EXPLAIN 비교와 별도로, 쿼리 재작성 시 데이터의 의미가 바뀌지 않았는지 확인하는 절차다.
*/
WITH or_result AS (
    SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        e.department_id,
        e.job_id
    FROM hr.employees AS e
    WHERE e.department_id = 10
       OR e.job_id IN (3, 4, 5)
),
union_all_result AS (
    SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        e.department_id,
        e.job_id
    FROM hr.employees AS e
    WHERE e.department_id = 10

    UNION ALL

    SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        e.department_id,
        e.job_id
    FROM hr.employees AS e
    WHERE e.job_id IN (3, 4, 5)
      AND e.department_id <> 10
),
differences AS (
    (SELECT * FROM or_result EXCEPT SELECT * FROM union_all_result)
    UNION ALL
    (SELECT * FROM union_all_result EXCEPT SELECT * FROM or_result)
)
SELECT COUNT(*) AS difference_count
FROM differences;

