SET search_path TO academic_management, public;

-- 1. 테이블 10개 생성 여부
SELECT
    table_name
FROM information_schema.tables
WHERE table_schema = 'academic_management'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- 2. 컬럼, 자료형, NULL 허용, DEFAULT, identity 확인
SELECT
    table_name,
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default,
    is_identity,
    identity_generation
FROM information_schema.columns
WHERE table_schema = 'academic_management'
ORDER BY table_name, ordinal_position;

-- 3. PRIMARY KEY 및 UNIQUE 제약 확인
SELECT
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.ordinal_position,
    kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_schema = tc.constraint_schema
 AND kcu.constraint_name = tc.constraint_name
 AND kcu.table_name = tc.table_name
WHERE tc.constraint_schema = 'academic_management'
  AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
ORDER BY tc.table_name, tc.constraint_name, kcu.ordinal_position;

-- 4. FOREIGN KEY와 참조 대상 확인
SELECT
    tc.table_name AS child_table,
    tc.constraint_name,
    kcu.column_name AS child_column,
    ccu.table_name AS parent_table,
    ccu.column_name AS parent_column,
    rc.update_rule,
    rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_schema = tc.constraint_schema
 AND kcu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
  ON rc.constraint_schema = tc.constraint_schema
 AND rc.constraint_name = tc.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_schema = rc.unique_constraint_schema
 AND ccu.constraint_name = rc.unique_constraint_name
WHERE tc.constraint_schema = 'academic_management'
  AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name, tc.constraint_name, kcu.ordinal_position;

-- 5. CHECK 제약 확인
SELECT
    tc.table_name,
    tc.constraint_name,
    cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc
  ON cc.constraint_schema = tc.constraint_schema
 AND cc.constraint_name = tc.constraint_name
WHERE tc.constraint_schema = 'academic_management'
  AND tc.constraint_type = 'CHECK'
ORDER BY tc.table_name, tc.constraint_name;

-- 6. 인덱스 확인
SELECT
    tablename AS table_name,
    indexname AS index_name,
    indexdef AS index_definition
FROM pg_catalog.pg_indexes
WHERE schemaname = 'academic_management'
ORDER BY tablename, indexname;

-- 7. STUDENT와 PROFESSOR의 상속키 구조 확인
SELECT
    tc.table_name,
    kcu.column_name,
    STRING_AGG(DISTINCT tc.constraint_type, ', ' ORDER BY tc.constraint_type) AS constraint_types
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_schema = tc.constraint_schema
 AND kcu.constraint_name = tc.constraint_name
 AND kcu.table_name = tc.table_name
WHERE tc.constraint_schema = 'academic_management'
  AND tc.table_name IN ('student', 'professor')
  AND kcu.column_name = 'person_id'
  AND tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
GROUP BY tc.table_name, kcu.column_name
ORDER BY tc.table_name;

-- 8. 테이블별 샘플 데이터 건수 확인
SELECT 'person' AS table_name, COUNT(*) AS row_count FROM person
UNION ALL
SELECT 'student', COUNT(*) FROM student
UNION ALL
SELECT 'professor', COUNT(*) FROM professor
UNION ALL
SELECT 'department', COUNT(*) FROM department
UNION ALL
SELECT 'degree_program', COUNT(*) FROM degree_program
UNION ALL
SELECT 'course', COUNT(*) FROM course
UNION ALL
SELECT 'semester', COUNT(*) FROM semester
UNION ALL
SELECT 'class_section', COUNT(*) FROM class_section
UNION ALL
SELECT 'class_schedule', COUNT(*) FROM class_schedule
UNION ALL
SELECT 'enrollment', COUNT(*) FROM enrollment
ORDER BY table_name;
