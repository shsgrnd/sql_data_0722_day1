SET search_path TO academic_management, public;

-- 1. 학생, 인적정보, 학과, 학위과정, 지도교수 조회
SELECT
    s.student_number,
    sp.name AS student_name,
    d.department_name,
    dp.program_name,
    s.academic_status,
    COALESCE(ap.name, '미지정') AS advisor_name
FROM student s
JOIN person sp ON sp.person_id = s.person_id
JOIN department d ON d.department_id = s.department_id
JOIN degree_program dp ON dp.degree_program_id = s.degree_program_id
LEFT JOIN professor pr ON pr.person_id = s.advisor_id
LEFT JOIN person ap ON ap.person_id = pr.person_id
ORDER BY s.student_number;

-- 2. 교수와 소속 학과 조회
SELECT
    pr.professor_number,
    p.name AS professor_name,
    d.department_name,
    pr.position,
    COALESCE(pr.office_location, '미지정') AS office_location
FROM professor pr
JOIN person p ON p.person_id = pr.person_id
JOIN department d ON d.department_id = pr.department_id
ORDER BY pr.professor_number;

-- 3. 개설강의, 교과목, 학기, 담당교수 조회
SELECT
    c.course_code,
    c.course_name,
    se.academic_year,
    se.term,
    cs.section_number,
    p.name AS professor_name,
    cs.capacity
FROM class_section cs
JOIN course c ON c.course_id = cs.course_id
JOIN semester se ON se.semester_id = cs.semester_id
JOIN professor pr ON pr.person_id = cs.professor_id
JOIN person p ON p.person_id = pr.person_id
ORDER BY se.academic_year, se.start_date, c.course_code, cs.section_number;

-- 4. 개설강의의 요일, 시간, 강의실 조회
SELECT
    c.course_code,
    c.course_name,
    cs.section_number,
    sch.day_of_week,
    sch.start_time,
    sch.end_time,
    COALESCE(sch.classroom, '온라인 또는 미정') AS classroom
FROM class_schedule sch
JOIN class_section cs ON cs.class_section_id = sch.class_section_id
JOIN course c ON c.course_id = cs.course_id
ORDER BY c.course_code, sch.day_of_week, sch.start_time;

-- 5. 학생별 수강 교과목과 성적 조회
SELECT
    s.student_number,
    p.name AS student_name,
    c.course_code,
    c.course_name,
    se.academic_year,
    se.term,
    e.enrollment_status,
    COALESCE(e.score::text, '미확정') AS score,
    COALESCE(e.grade, '미확정') AS grade
FROM enrollment e
JOIN student s ON s.person_id = e.student_id
JOIN person p ON p.person_id = s.person_id
JOIN class_section cs ON cs.class_section_id = e.class_section_id
JOIN course c ON c.course_id = cs.course_id
JOIN semester se ON se.semester_id = cs.semester_id
ORDER BY s.student_number, se.academic_year, se.start_date, c.course_code;

-- 6. 분반별 수강 인원 및 잔여 정원 조회
SELECT
    c.course_code,
    c.course_name,
    cs.section_number,
    cs.capacity,
    COUNT(e.enrollment_id) FILTER (
        WHERE e.enrollment_status <> '취소'
    ) AS enrolled_count,
    cs.capacity - COUNT(e.enrollment_id) FILTER (
        WHERE e.enrollment_status <> '취소'
    ) AS remaining_capacity
FROM class_section cs
JOIN course c ON c.course_id = cs.course_id
LEFT JOIN enrollment e ON e.class_section_id = cs.class_section_id
GROUP BY
    cs.class_section_id,
    c.course_code,
    c.course_name,
    cs.section_number,
    cs.capacity
ORDER BY c.course_code, cs.section_number;

-- 7. 교수별 지도학생 수
SELECT
    pr.professor_number,
    p.name AS professor_name,
    COUNT(s.person_id) AS advisee_count
FROM professor pr
JOIN person p ON p.person_id = pr.person_id
LEFT JOIN student s ON s.advisor_id = pr.person_id
GROUP BY pr.person_id, pr.professor_number, p.name
ORDER BY pr.professor_number;

-- 8. 학과별 학생, 교수, 교과목 수
SELECT
    d.department_code,
    d.department_name,
    COUNT(DISTINCT s.person_id) AS student_count,
    COUNT(DISTINCT pr.person_id) AS professor_count,
    COUNT(DISTINCT c.course_id) AS course_count
FROM department d
LEFT JOIN student s ON s.department_id = d.department_id
LEFT JOIN professor pr ON pr.department_id = d.department_id
LEFT JOIN course c ON c.department_id = d.department_id
GROUP BY d.department_id, d.department_code, d.department_name
ORDER BY d.department_code;
