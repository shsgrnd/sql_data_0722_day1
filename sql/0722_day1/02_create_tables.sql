BEGIN;

CREATE SCHEMA IF NOT EXISTS academic_management;
SET LOCAL search_path TO academic_management, public;

CREATE TABLE department (
    department_id bigint GENERATED ALWAYS AS IDENTITY,
    department_code varchar(20) NOT NULL,
    department_name varchar(100) NOT NULL,
    office_location varchar(100),
    phone varchar(30),
    CONSTRAINT pk_department PRIMARY KEY (department_id),
    CONSTRAINT uq_department_code UNIQUE (department_code),
    CONSTRAINT uq_department_name UNIQUE (department_name)
);

CREATE TABLE degree_program (
    degree_program_id bigint GENERATED ALWAYS AS IDENTITY,
    program_name varchar(20) NOT NULL,
    standard_years smallint NOT NULL,
    required_credits smallint NOT NULL,
    description text,
    CONSTRAINT pk_degree_program PRIMARY KEY (degree_program_id),
    CONSTRAINT uq_degree_program_name UNIQUE (program_name),
    CONSTRAINT ck_degree_program_name
        CHECK (program_name IN ('학사', '석사', '박사')),
    CONSTRAINT ck_degree_program_standard_years
        CHECK (standard_years >= 1),
    CONSTRAINT ck_degree_program_required_credits
        CHECK (required_credits >= 0)
);

CREATE TABLE semester (
    semester_id bigint GENERATED ALWAYS AS IDENTITY,
    academic_year integer NOT NULL,
    term varchar(20) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    registration_start date NOT NULL,
    registration_end date NOT NULL,
    CONSTRAINT pk_semester PRIMARY KEY (semester_id),
    CONSTRAINT uq_semester_academic_year_term
        UNIQUE (academic_year, term),
    CONSTRAINT ck_semester_term
        CHECK (term IN ('1학기', '2학기', '여름학기', '겨울학기')),
    CONSTRAINT ck_semester_date_range
        CHECK (start_date < end_date),
    CONSTRAINT ck_semester_registration_range
        CHECK (registration_start <= registration_end)
);

CREATE TABLE person (
    person_id bigint GENERATED ALWAYS AS IDENTITY,
    name varchar(100) NOT NULL,
    email varchar(254) NOT NULL,
    phone varchar(30),
    birth_date date NOT NULL,
    address text,
    CONSTRAINT pk_person PRIMARY KEY (person_id),
    CONSTRAINT uq_person_email UNIQUE (email),
    CONSTRAINT ck_person_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT ck_person_birth_date CHECK (birth_date <= CURRENT_DATE)
);

CREATE TABLE professor (
    person_id bigint NOT NULL,
    professor_number varchar(30) NOT NULL,
    department_id bigint NOT NULL,
    appointment_date date NOT NULL,
    position varchar(20) NOT NULL,
    office_location varchar(100),
    CONSTRAINT pk_professor PRIMARY KEY (person_id),
    CONSTRAINT fk_professor_person
        FOREIGN KEY (person_id)
        REFERENCES person (person_id)
        ON UPDATE NO ACTION
        ON DELETE CASCADE,
    CONSTRAINT fk_professor_department
        FOREIGN KEY (department_id)
        REFERENCES department (department_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT uq_professor_number UNIQUE (professor_number),
    CONSTRAINT ck_professor_appointment_date
        CHECK (appointment_date <= CURRENT_DATE),
    CONSTRAINT ck_professor_position
        CHECK (position IN ('전임강사', '조교수', '부교수', '교수'))
);

CREATE TABLE student (
    person_id bigint NOT NULL,
    student_number varchar(30) NOT NULL,
    department_id bigint NOT NULL,
    degree_program_id bigint NOT NULL,
    advisor_id bigint,
    admission_date date NOT NULL,
    academic_status varchar(20) NOT NULL DEFAULT '재학',
    current_semester smallint NOT NULL DEFAULT 1,
    CONSTRAINT pk_student PRIMARY KEY (person_id),
    CONSTRAINT fk_student_person
        FOREIGN KEY (person_id)
        REFERENCES person (person_id)
        ON UPDATE NO ACTION
        ON DELETE CASCADE,
    CONSTRAINT fk_student_department
        FOREIGN KEY (department_id)
        REFERENCES department (department_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_student_degree_program
        FOREIGN KEY (degree_program_id)
        REFERENCES degree_program (degree_program_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_student_advisor
        FOREIGN KEY (advisor_id)
        REFERENCES professor (person_id)
        ON UPDATE NO ACTION
        ON DELETE SET NULL,
    CONSTRAINT uq_student_number UNIQUE (student_number),
    CONSTRAINT ck_student_admission_date
        CHECK (admission_date <= CURRENT_DATE),
    CONSTRAINT ck_student_academic_status
        CHECK (academic_status IN ('재학', '휴학', '수료', '졸업', '제적')),
    CONSTRAINT ck_student_current_semester
        CHECK (current_semester >= 1)
);

CREATE TABLE course (
    course_id bigint GENERATED ALWAYS AS IDENTITY,
    course_code varchar(30) NOT NULL,
    course_name varchar(150) NOT NULL,
    department_id bigint NOT NULL,
    credits smallint NOT NULL,
    course_level varchar(20) NOT NULL,
    description text,
    CONSTRAINT pk_course PRIMARY KEY (course_id),
    CONSTRAINT fk_course_department
        FOREIGN KEY (department_id)
        REFERENCES department (department_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT uq_course_code UNIQUE (course_code),
    CONSTRAINT ck_course_credits CHECK (credits >= 1),
    CONSTRAINT ck_course_level
        CHECK (course_level IN ('학부', '대학원', '공통'))
);

CREATE TABLE class_section (
    class_section_id bigint GENERATED ALWAYS AS IDENTITY,
    course_id bigint NOT NULL,
    semester_id bigint NOT NULL,
    professor_id bigint NOT NULL,
    section_number varchar(20) NOT NULL,
    capacity integer NOT NULL,
    CONSTRAINT pk_class_section PRIMARY KEY (class_section_id),
    CONSTRAINT fk_class_section_course
        FOREIGN KEY (course_id)
        REFERENCES course (course_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_class_section_semester
        FOREIGN KEY (semester_id)
        REFERENCES semester (semester_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_class_section_professor
        FOREIGN KEY (professor_id)
        REFERENCES professor (person_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT uq_class_section_course_semester_number
        UNIQUE (course_id, semester_id, section_number),
    CONSTRAINT ck_class_section_capacity CHECK (capacity >= 1)
);

CREATE TABLE class_schedule (
    class_schedule_id bigint GENERATED ALWAYS AS IDENTITY,
    class_section_id bigint NOT NULL,
    day_of_week varchar(10) NOT NULL,
    start_time time NOT NULL,
    end_time time NOT NULL,
    classroom varchar(100),
    CONSTRAINT pk_class_schedule PRIMARY KEY (class_schedule_id),
    CONSTRAINT fk_class_schedule_section
        FOREIGN KEY (class_section_id)
        REFERENCES class_section (class_section_id)
        ON UPDATE NO ACTION
        ON DELETE CASCADE,
    CONSTRAINT uq_class_schedule_section_day_start
        UNIQUE (class_section_id, day_of_week, start_time),
    CONSTRAINT ck_class_schedule_day_of_week
        CHECK (day_of_week IN ('월', '화', '수', '목', '금', '토')),
    CONSTRAINT ck_class_schedule_time_range
        CHECK (start_time < end_time)
);

CREATE TABLE enrollment (
    enrollment_id bigint GENERATED ALWAYS AS IDENTITY,
    student_id bigint NOT NULL,
    class_section_id bigint NOT NULL,
    enrollment_date date NOT NULL DEFAULT CURRENT_DATE,
    enrollment_status varchar(20) NOT NULL DEFAULT '수강중',
    score numeric(5, 2),
    grade varchar(2),
    CONSTRAINT pk_enrollment PRIMARY KEY (enrollment_id),
    CONSTRAINT fk_enrollment_student
        FOREIGN KEY (student_id)
        REFERENCES student (person_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_enrollment_class_section
        FOREIGN KEY (class_section_id)
        REFERENCES class_section (class_section_id)
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT uq_enrollment_student_section
        UNIQUE (student_id, class_section_id),
    CONSTRAINT ck_enrollment_status
        CHECK (enrollment_status IN ('수강중', '이수', '취소', '재수강')),
    CONSTRAINT ck_enrollment_score
        CHECK (score IS NULL OR score BETWEEN 0 AND 100),
    CONSTRAINT ck_enrollment_grade
        CHECK (
            grade IS NULL
            OR grade IN ('A+', 'A0', 'B+', 'B0', 'C+', 'C0', 'D+', 'D0', 'F')
        )
);

CREATE INDEX idx_student_department_id
    ON student (department_id);

CREATE INDEX idx_student_degree_program_id
    ON student (degree_program_id);

CREATE INDEX idx_student_advisor_id
    ON student (advisor_id);

CREATE INDEX idx_professor_department_id
    ON professor (department_id);

CREATE INDEX idx_course_department_id
    ON course (department_id);

CREATE INDEX idx_class_section_semester_id
    ON class_section (semester_id);

CREATE INDEX idx_class_section_professor_id
    ON class_section (professor_id);

CREATE INDEX idx_enrollment_class_section_id
    ON enrollment (class_section_id);

COMMIT;
