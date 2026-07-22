SET search_path TO academic_management, public;

-- 1. 테이블별 전체 데이터 조회
SELECT * FROM person ORDER BY person_id;
SELECT * FROM student ORDER BY student_number;
SELECT * FROM professor ORDER BY professor_number;
SELECT * FROM department ORDER BY department_code;
SELECT * FROM degree_program ORDER BY degree_program_id;
SELECT * FROM course ORDER BY course_code;
SELECT * FROM semester ORDER BY academic_year, term;
SELECT * FROM class_section ORDER BY class_section_id;
SELECT * FROM class_schedule ORDER BY class_section_id, day_of_week, start_time;
SELECT * FROM enrollment ORDER BY enrollment_id;

-- 2. WHERE 조건 조회: 재학생
SELECT
    student_number,
    academic_status,
    current_semester
FROM student
WHERE academic_status = '재학'
ORDER BY student_number;

-- 3. ORDER BY 조회: 학점이 높은 교과목부터 정렬
SELECT
    course_code,
    course_name,
    credits,
    course_level
FROM course
ORDER BY credits DESC, course_code;

-- 4. 복합 조건 조회: 학부 과정의 3학점 이상 교과목
SELECT
    course_code,
    course_name,
    credits,
    course_level
FROM course
WHERE course_level = '학부'
  AND credits >= 3
ORDER BY course_name;

-- 5. NULL 조건 조회: 지도교수가 지정되지 않은 학생
SELECT
    student_number,
    person_id,
    advisor_id
FROM student
WHERE advisor_id IS NULL
ORDER BY student_number;

-- 6. 범위 조건 조회: 80점 이상 성적
SELECT
    enrollment_id,
    student_id,
    class_section_id,
    score,
    grade
FROM enrollment
WHERE score >= 80
ORDER BY score DESC;
