BEGIN;

SET LOCAL search_path TO academic_management, public;

INSERT INTO department (
    department_code,
    department_name,
    office_location,
    phone
) VALUES
    ('CSE', '컴퓨터공학과', '공학관 301호', '02-1000-1001'),
    ('MSE', '기계공학과', '공학관 401호', '02-1000-1002'),
    ('EE', '전자공학과', '공학관 501호', '02-1000-1003'),
    ('BA', '경영학과', '경영관 201호', '02-1000-1004'),
    ('ECO', '경제학과', '사회관 301호', '02-1000-1005'),
    ('KOR', '국어국문학과', '인문관 201호', '02-1000-1006'),
    ('ENG', '영어영문학과', '인문관 301호', '02-1000-1007'),
    ('MATH', '수학과', '자연관 201호', '02-1000-1008'),
    ('PHY', '물리학과', '자연관 301호', '02-1000-1009'),
    ('CHEM', '화학과', '자연관 401호', '02-1000-1010');

INSERT INTO degree_program (
    program_name,
    standard_years,
    required_credits,
    description
) VALUES
    ('학사', 4, 130, '학부 학위과정'),
    ('석사', 2, 24, '석사 학위과정'),
    ('박사', 4, 36, '박사 학위과정');

INSERT INTO semester (
    academic_year,
    term,
    start_date,
    end_date,
    registration_start,
    registration_end
) VALUES
    (2024, '1학기', '2024-03-04', '2024-06-21', '2024-02-12', '2024-02-16'),
    (2024, '2학기', '2024-09-02', '2024-12-20', '2024-08-12', '2024-08-16'),
    (2025, '1학기', '2025-03-04', '2025-06-20', '2025-02-10', '2025-02-14'),
    (2025, '여름학기', '2025-06-30', '2025-07-25', '2025-06-16', '2025-06-18'),
    (2025, '2학기', '2025-09-01', '2025-12-19', '2025-08-11', '2025-08-15'),
    (2025, '겨울학기', '2025-12-29', '2026-01-23', '2025-12-15', '2025-12-17'),
    (2026, '1학기', '2026-03-03', '2026-06-19', '2026-02-09', '2026-02-13'),
    (2026, '여름학기', '2026-06-29', '2026-07-24', '2026-06-15', '2026-06-17'),
    (2026, '2학기', '2026-09-01', '2026-12-18', '2026-08-10', '2026-08-14'),
    (2026, '겨울학기', '2026-12-28', '2027-01-22', '2026-12-14', '2026-12-16');

INSERT INTO person (name, email, phone, birth_date, address) VALUES
    ('이상혁', 'prof01@example.ac.kr', '010-1000-0001', '1996-05-07', '서울특별시 서초구'),
    ('이지훈', 'prof02@example.ac.kr', '010-1000-0002', '1992-11-23', '서울특별시 서초구'),
    ('유나얼', 'prof03@example.ac.kr', '010-1000-0003', '1978-09-23', '서울특별시 성북구'),
    ('이수현', 'prof04@example.ac.kr', NULL, '1999-05-04', '서울특별시 마포구'),
    ('이선웅', 'prof05@example.ac.kr', '010-1000-0005', '1980-07-22', '서울특별시 강남구'),
    ('장경환', 'prof06@example.ac.kr', '010-1000-0006', '1991-02-12', '서울특별시 강남구'),
    ('권지용', 'prof07@example.ac.kr', '010-1000-0007', '1988-08-18', '서울특별시 용산구'),
    ('동영배', 'prof08@example.ac.kr', '010-1000-0008', '1988-05-18', '서울특별시 용산구'),
    ('강대성', 'prof09@example.ac.kr', NULL, '1989-04-26', '서울특별시 구로구'),
    ('최진', 'prof10@example.ac.kr', '010-1000-0010', '1983-01-06', '전라남도 고흥군'),
    ('이찬혁', 'student01@example.ac.kr', '010-2000-0001', '1996-09-12', '서울특별시 마포구'),
    ('최현준', 'student02@example.ac.kr', '010-2000-0002', '2002-02-23', '서울특별시 서초구'),
    ('김수환', 'student03@example.ac.kr', NULL, '2005-03-08', '서울특별시 서초구'),
    ('김은혜', 'student04@example.ac.kr', '010-2000-0004', '1992-01-11', '경기도 남양주시'),
    ('방시우', 'student05@example.ac.kr', '010-2000-0005', '1989-06-24', NULL),
    ('김정식', 'student06@example.ac.kr', '010-2000-0006', '1981-11-19', '서울특별시 성북구'),
    ('이무진', 'student07@example.ac.kr', '010-2000-0007', '1999-07-16', '경기도 안양시'),
    ('유지민', 'student08@example.ac.kr', NULL, '2000-08-04', '서울특별시 노원구'),
    ('배주현', 'student09@example.ac.kr', '010-2000-0009', '2002-09-29', '인천광역시 남동구'),
    ('성시경', 'student10@example.ac.kr', '010-2000-0010', '2001-10-10', '서울특별시 관악구');

INSERT INTO professor (
    person_id,
    professor_number,
    department_id,
    appointment_date,
    position,
    office_location
)
SELECT
    p.person_id,
    source.professor_number,
    d.department_id,
    source.appointment_date,
    source.position,
    source.office_location
FROM (
    VALUES
        ('prof01@example.ac.kr', 'P1001', 'CSE', DATE '2005-03-01', '교수', '공학관 311호'),
        ('prof02@example.ac.kr', 'P1002', 'MSE', DATE '2008-03-01', '교수', '공학관 411호'),
        ('prof03@example.ac.kr', 'P1003', 'EE', DATE '2010-09-01', '교수', '공학관 511호'),
        ('prof04@example.ac.kr', 'P1004', 'BA', DATE '2001-03-01', '교수', '경영관 211호'),
        ('prof05@example.ac.kr', 'P1005', 'ECO', DATE '2012-03-01', '교수', '사회관 311호'),
        ('prof06@example.ac.kr', 'P1006', 'KOR', DATE '2007-09-01', '부교수', '인문관 211호'),
        ('prof07@example.ac.kr', 'P1007', 'ENG', DATE '2016-03-01', '교수', '인문관 311호'),
        ('prof08@example.ac.kr', 'P1008', 'MATH', DATE '2009-03-01', '교수', '자연관 211호'),
        ('prof09@example.ac.kr', 'P1009', 'PHY', DATE '2015-09-01', '부교수', NULL),
        ('prof10@example.ac.kr', 'P1010', 'CHEM', DATE '2003-03-01', '교수', '자연관 411호')
) AS source(email, professor_number, department_code, appointment_date, position, office_location)
JOIN person p ON p.email = source.email
JOIN department d ON d.department_code = source.department_code;

INSERT INTO student (
    person_id,
    student_number,
    department_id,
    degree_program_id,
    advisor_id,
    admission_date,
    academic_status,
    current_semester
)
SELECT
    p.person_id,
    source.student_number,
    d.department_id,
    dp.degree_program_id,
    advisor.person_id,
    source.admission_date,
    source.academic_status,
    source.current_semester
FROM (
    VALUES
        ('student01@example.ac.kr', 'S2026001', 'CSE', '학사', 'P1001', DATE '2026-03-03', '재학', 1),
        ('student02@example.ac.kr', 'S2025002', 'MSE', '학사', 'P1002', DATE '2025-03-04', '재학', 3),
        ('student03@example.ac.kr', 'S2024003', 'EE', '학사', 'P1003', DATE '2024-03-04', '휴학', 4),
        ('student04@example.ac.kr', 'S2023004', 'BA', '학사', 'P1004', DATE '2023-03-02', '재학', 7),
        ('student05@example.ac.kr', 'S2026005', 'ECO', '학사', NULL, DATE '2026-03-03', '재학', 1),
        ('student06@example.ac.kr', 'S2025006', 'KOR', '석사', 'P1006', DATE '2025-03-04', '재학', 3),
        ('student07@example.ac.kr', 'S2024007', 'ENG', '석사', 'P1007', DATE '2024-03-04', '수료', 4),
        ('student08@example.ac.kr', 'S2026008', 'MATH', '박사', 'P1008', DATE '2026-03-03', '재학', 1),
        ('student09@example.ac.kr', 'S2025009', 'PHY', '박사', 'P1009', DATE '2025-03-04', '재학', 3),
        ('student10@example.ac.kr', 'S2020010', 'CHEM', '학사', 'P1010', DATE '2020-03-02', '졸업', 8)
) AS source(
    email,
    student_number,
    department_code,
    program_name,
    advisor_number,
    admission_date,
    academic_status,
    current_semester
)
JOIN person p ON p.email = source.email
JOIN department d ON d.department_code = source.department_code
JOIN degree_program dp ON dp.program_name = source.program_name
LEFT JOIN professor advisor ON advisor.professor_number = source.advisor_number;

INSERT INTO course (
    course_code,
    course_name,
    department_id,
    credits,
    course_level,
    description
)
SELECT
    source.course_code,
    source.course_name,
    d.department_id,
    source.credits,
    source.course_level,
    source.description
FROM (
    VALUES
        ('CSE101', '프로그래밍기초', 'CSE', 3, '학부', '프로그래밍 기본 개념'),
        ('MSE201', '열역학', 'MSE', 3, '학부', '열과 에너지의 기본 원리'),
        ('EE201', '회로이론', 'EE', 3, '학부', '전기 회로 해석'),
        ('BA101', '경영학원론', 'BA', 3, '학부', '경영학의 기초'),
        ('ECO201', '미시경제학', 'ECO', 3, '학부', '미시경제 이론'),
        ('KOR301', '한국문학연구', 'KOR', 3, '대학원', '한국문학 연구 방법론'),
        ('ENG301', '영문학연구', 'ENG', 3, '대학원', '영문학 연구 방법론'),
        ('MATH501', '고급해석학', 'MATH', 3, '대학원', '해석학 심화 과정'),
        ('PHY501', '양자역학특론', 'PHY', 3, '대학원', '양자역학 심화 과정'),
        ('CHEM100', '생활속의화학', 'CHEM', 2, '공통', NULL)
) AS source(course_code, course_name, department_code, credits, course_level, description)
JOIN department d ON d.department_code = source.department_code;

INSERT INTO class_section (
    course_id,
    semester_id,
    professor_id,
    section_number,
    capacity
)
SELECT
    c.course_id,
    s.semester_id,
    p.person_id,
    source.section_number,
    source.capacity
FROM (
    VALUES
        ('CSE101', 'P1001', '01', 40),
        ('MSE201', 'P1002', '01', 35),
        ('EE201', 'P1003', '01', 35),
        ('BA101', 'P1004', '01', 50),
        ('ECO201', 'P1005', '01', 45),
        ('KOR301', 'P1006', '01', 20),
        ('ENG301', 'P1007', '01', 20),
        ('MATH501', 'P1008', '01', 15),
        ('PHY501', 'P1009', '01', 15),
        ('CHEM100', 'P1010', '01', 60)
) AS source(course_code, professor_number, section_number, capacity)
JOIN course c ON c.course_code = source.course_code
JOIN professor p ON p.professor_number = source.professor_number
JOIN semester s ON s.academic_year = 2026 AND s.term = '1학기';

INSERT INTO class_schedule (
    class_section_id,
    day_of_week,
    start_time,
    end_time,
    classroom
)
SELECT
    cs.class_section_id,
    source.day_of_week,
    source.start_time,
    source.end_time,
    source.classroom
FROM (
    VALUES
        ('CSE101', '월', TIME '09:00', TIME '10:30', '공학관 101호'),
        ('MSE201', '화', TIME '09:00', TIME '10:30', '공학관 201호'),
        ('EE201', '수', TIME '10:30', TIME '12:00', '공학관 202호'),
        ('BA101', '목', TIME '09:00', TIME '10:30', '경영관 101호'),
        ('ECO201', '금', TIME '10:30', TIME '12:00', '사회관 101호'),
        ('KOR301', '월', TIME '13:00', TIME '14:30', '인문관 101호'),
        ('ENG301', '화', TIME '13:00', TIME '14:30', '인문관 102호'),
        ('MATH501', '수', TIME '15:00', TIME '16:30', '자연관 101호'),
        ('PHY501', '목', TIME '15:00', TIME '16:30', '자연관 102호'),
        ('CHEM100', '토', TIME '10:00', TIME '12:00', NULL)
) AS source(course_code, day_of_week, start_time, end_time, classroom)
JOIN course c ON c.course_code = source.course_code
JOIN class_section cs ON cs.course_id = c.course_id
JOIN semester s
    ON s.semester_id = cs.semester_id
   AND s.academic_year = 2026
   AND s.term = '1학기';

INSERT INTO enrollment (
    student_id,
    class_section_id,
    enrollment_date,
    enrollment_status,
    score,
    grade
)
SELECT
    st.person_id,
    cs.class_section_id,
    source.enrollment_date,
    source.enrollment_status,
    source.score,
    source.grade
FROM (
    VALUES
        ('S2026001', 'CSE101', DATE '2026-02-09', '수강중', NULL::numeric, NULL::varchar),
        ('S2025002', 'MSE201', DATE '2026-02-09', '수강중', NULL::numeric, NULL::varchar),
        ('S2024003', 'EE201', DATE '2026-02-10', '취소', NULL::numeric, NULL::varchar),
        ('S2023004', 'BA101', DATE '2026-02-10', '이수', 95.50::numeric, 'A+'),
        ('S2026005', 'ECO201', DATE '2026-02-11', '수강중', NULL::numeric, NULL::varchar),
        ('S2025006', 'KOR301', DATE '2026-02-11', '이수', 88.00::numeric, 'B+'),
        ('S2024007', 'ENG301', DATE '2026-02-12', '재수강', 76.00::numeric, 'C+'),
        ('S2026008', 'MATH501', DATE '2026-02-12', '수강중', NULL::numeric, NULL::varchar),
        ('S2025009', 'PHY501', DATE '2026-02-13', '이수', 82.00::numeric, 'B0'),
        ('S2020010', 'CHEM100', DATE '2026-02-13', '이수', 59.00::numeric, 'F')
) AS source(
    student_number,
    course_code,
    enrollment_date,
    enrollment_status,
    score,
    grade
)
JOIN student st ON st.student_number = source.student_number
JOIN course c ON c.course_code = source.course_code
JOIN class_section cs ON cs.course_id = c.course_id
JOIN semester s
    ON s.semester_id = cs.semester_id
   AND s.academic_year = 2026
   AND s.term = '1학기';

COMMIT;
