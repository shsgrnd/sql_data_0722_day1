SET search_path TO academic_management, public;

-- 1. COALESCE: 미입력 연락처와 주소를 대체하여 표시
SELECT
    person_id,
    name,
    COALESCE(phone, '연락처 없음') AS phone,
    COALESCE(address, '주소 없음') AS address
FROM person
ORDER BY person_id;

-- 2. COALESCE: 미확정 점수와 등급을 대체하여 표시
SELECT
    enrollment_id,
    COALESCE(score::text, '미확정') AS score,
    COALESCE(grade, '미확정') AS grade
FROM enrollment
ORDER BY enrollment_id;

-- 3. CASE WHEN: 점수 구간 분류
SELECT
    enrollment_id,
    score,
    CASE
        WHEN score IS NULL THEN '미평가'
        WHEN score >= 90 THEN '우수'
        WHEN score >= 80 THEN '양호'
        WHEN score >= 70 THEN '보통'
        ELSE '보완 필요'
    END AS score_level
FROM enrollment
ORDER BY enrollment_id;

-- 4. CASE WHEN: 학생의 학기 단계 분류
SELECT
    student_number,
    current_semester,
    CASE
        WHEN current_semester <= 2 THEN '초기'
        WHEN current_semester <= 6 THEN '중기'
        ELSE '후기'
    END AS semester_stage
FROM student
ORDER BY student_number;

-- 5. 날짜 함수: 나이와 출생연도 계산
SELECT
    person_id,
    name,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date))::integer AS age,
    EXTRACT(YEAR FROM birth_date)::integer AS birth_year
FROM person
ORDER BY person_id;

-- 6. 날짜 함수: 학기 기간 계산
SELECT
    academic_year,
    term,
    start_date,
    end_date,
    end_date - start_date AS semester_days
FROM semester
ORDER BY academic_year, start_date;

-- 7. 집계 함수: 학적 상태별 학생 수
SELECT
    academic_status,
    COUNT(*) AS student_count
FROM student
GROUP BY academic_status
ORDER BY academic_status;
