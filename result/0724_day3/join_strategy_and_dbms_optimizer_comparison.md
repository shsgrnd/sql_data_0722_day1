# 조인 전략 비교 및 DBMS 엔진별 옵티마이저 특징

> 작성 기준: 2026-07-24  
> 대상 DBMS: PostgreSQL, MySQL, Oracle Database, Microsoft SQL Server

## 1. 조인 전략 비교

SQL의 `INNER JOIN`, `LEFT JOIN` 등은 어떤 데이터를 결합할지를 표현하는 **논리적 조인**이다. 실제 실행 과정에서는 옵티마이저가 통계 정보, 예상 행 수, 인덱스, 정렬 상태, 메모리, 병렬 처리 가능성 등을 고려하여 Nested Loop Join, Hash Join, Merge Join과 같은 **물리적 조인 방식**을 선택한다.

따라서 동일한 SQL이라도 데이터 분포나 인덱스 상태가 달라지면 실행 계획의 조인 방식이 달라질 수 있다.

---

## 2. Nested Loop Join

### 2.1 동작 원리

Nested Loop Join은 외부 입력의 각 행에 대해 내부 입력에서 조인 조건을 만족하는 행을 반복해서 찾는 방식이다.

```text
for each row in outer_input:
    search matching rows in inner_input
```

내부 입력의 조인 컬럼에 인덱스가 있으면 각 반복에서 전체 테이블을 탐색하지 않고 Index Scan 또는 Index Seek를 수행할 수 있다.

### 2.2 적합한 상황

- 외부 입력의 예상 행 수가 적은 경우
- 내부 테이블의 조인 컬럼에 적절한 인덱스가 있는 경우
- `WHERE` 조건의 선택도가 높아 소수의 행만 남는 경우
- OLTP 환경처럼 소량의 데이터를 빠르게 조회하는 경우
- 첫 번째 결과를 빠르게 반환해야 하는 경우

### 2.3 장점

- 소량 데이터 조인에서 효율적이다.
- 내부 테이블의 인덱스를 적극적으로 활용할 수 있다.
- 별도의 대규모 해시 테이블이나 정렬 작업이 필요하지 않다.
- 동등 조인뿐 아니라 범위 조건 등 다양한 조인 조건에 적용할 수 있다.

### 2.4 단점

- 외부 입력의 행 수가 많아지면 내부 탐색 횟수도 함께 증가한다.
- 내부 테이블에 적절한 인덱스가 없으면 반복적인 전체 스캔이 발생할 수 있다.
- 예상 행 수가 실제보다 작게 추정되면 대량 데이터에 잘못 선택되어 성능이 크게 저하될 수 있다.

### 2.5 개념적 비용

```text
외부 입력 행 수 × 내부 입력 탐색 비용
```

외부 입력에서 100,000행이 나오면 내부 입력 탐색도 최대 100,000회 수행될 수 있다. 따라서 Nested Loop Join에서는 외부 입력을 가능한 한 작게 만들고 내부 입력의 탐색 경로에 인덱스를 제공하는 것이 중요하다.

---

## 3. Hash Join

### 3.1 동작 원리

Hash Join은 일반적으로 상대적으로 작은 입력을 이용해 메모리에 해시 테이블을 만든 뒤, 다른 입력을 순차적으로 읽으면서 동일한 해시값을 가진 행을 찾는 방식이다.

```text
Build:
    작은 입력으로 해시 테이블 생성

Probe:
    큰 입력을 읽으면서 해시 테이블에서 일치 행 탐색
```

### 3.2 적합한 상황

- 두 입력에서 많은 행을 읽어야 하는 경우
- 조인 조건이 `=`인 동등 조인인 경우
- 조인 컬럼에 적절한 인덱스가 없는 경우
- 데이터웨어하우스, 통계, 배치 처리 등 대량 조회 환경
- 한쪽 입력을 메모리의 해시 테이블로 구성할 수 있는 경우

### 3.3 장점

- 대량 데이터의 동등 조인에 효율적이다.
- 조인 컬럼에 인덱스가 없어도 사용할 수 있다.
- 양쪽 입력을 반복 탐색하지 않고 대체로 한 번씩 읽는다.
- 전체 스캔이 필요한 상황에서는 Nested Loop Join보다 유리할 수 있다.
- 병렬 처리와 결합하기 좋다.

### 3.4 단점

- 기본적으로 동등 조인에 적합하며 범위 조인에는 사용할 수 없다.
- 해시 테이블을 생성할 메모리가 필요하다.
- 메모리가 부족하면 임시 디스크로 데이터가 유출되는 Spill이 발생할 수 있다.
- Build 입력을 처리한 후 결과를 반환하므로 첫 번째 행 반환이 늦을 수 있다.
- 데이터 편향이나 잘못된 카디널리티 추정에 영향을 받는다.

### 3.5 개념적 비용

```text
Build 입력 읽기 비용 + Probe 입력 읽기 비용
```

이상적인 경우 시간 복잡도는 대략 `O(N + M)`으로 볼 수 있다. 다만 실제 성능은 메모리 크기, 해시 충돌, 데이터 분포, 임시 디스크 사용 여부에 따라 달라진다.

---

## 4. Merge Join

### 4.1 동작 원리

Merge Join은 조인 키를 기준으로 정렬된 두 입력을 동시에 순차 탐색하면서 일치하는 값을 결합하는 방식이다.

```text
while left and right have rows:
    if left.key == right.key:
        output matching rows
    elif left.key < right.key:
        advance left
    else:
        advance right
```

입력이 인덱스 등을 통해 이미 정렬되어 있지 않다면 조인 전에 Sort 작업이 추가될 수 있다.

### 4.2 적합한 상황

- 양쪽 입력이 조인 키 기준으로 이미 정렬된 경우
- 정렬된 인덱스를 활용할 수 있는 경우
- 양쪽 입력의 행 수가 모두 많은 경우
- 대량 데이터의 동등 조인 또는 일부 범위 조인
- 결과 정렬이 이후 연산에도 활용될 수 있는 경우

### 4.3 장점

- 정렬이 완료된 대량 입력을 순차적으로 처리할 때 효율적이다.
- 양쪽 입력을 한 방향으로 읽기 때문에 반복 탐색이 적다.
- 동등 조인뿐 아니라 DBMS에 따라 일부 범위 조인에도 활용할 수 있다.
- 조인 키에 정렬된 인덱스가 있으면 별도의 Sort 비용을 피할 수 있다.

### 4.4 단점

- 입력이 정렬되어 있지 않으면 사전 Sort 비용이 발생한다.
- 정렬 데이터가 메모리를 초과하면 디스크 기반 정렬이 발생할 수 있다.
- 소량 조회에서는 Nested Loop Join보다 불리할 수 있다.
- 정렬 비용 때문에 Hash Join보다 비효율적인 실행 계획이 될 수 있다.

---

## 5. 조인 전략 종합 비교

| 구분 | Nested Loop Join | Hash Join | Merge Join |
|---|---|---|---|
| 기본 원리 | 외부 행마다 내부 입력 탐색 | 한쪽 입력으로 해시 생성 후 탐색 | 정렬된 양쪽 입력을 동시에 순차 탐색 |
| 적합한 데이터 규모 | 소량 | 대량 | 대량 |
| 주요 조인 조건 | 동등·범위 등 다양 | 주로 동등 조인 | 동등 및 일부 범위 조인 |
| 인덱스 의존도 | 높음 | 낮음 | 정렬 인덱스가 있으면 유리 |
| 추가 메모리 | 비교적 적음 | 해시 테이블 필요 | 정렬 메모리 필요 가능 |
| 디스크 Spill 위험 | 상대적으로 낮음 | 해시 배치 Spill | 정렬 Spill |
| 첫 행 반환 속도 | 빠른 편 | Build 이후 반환 | 정렬 필요 시 느림 |
| 대표적 사용 환경 | OLTP, 선택도 높은 조회 | DW, 배치, 전체 스캔 | 정렬된 대량 데이터 |

### 핵심 판단

- **소량 결과 + 내부 인덱스 존재**: Nested Loop Join이 유리할 가능성이 높다.
- **대량 동등 조인 + 인덱스 부족**: Hash Join이 유리할 가능성이 높다.
- **양쪽 입력이 이미 정렬됨**: Merge Join이 유리할 가능성이 높다.
- 실제 선택은 고정 규칙이 아니라 옵티마이저의 비용 계산 결과에 따라 달라진다.

---

# 6. DBMS 엔진별 옵티마이저 특징

## 6.1 PostgreSQL

PostgreSQL은 비용 기반 옵티마이저를 사용하며 Nested Loop, Hash Join, Merge Join을 모두 지원한다. 실행 계획은 트리 형태로 출력되며, 각 노드의 예상 비용과 예상 행 수를 확인할 수 있다.

### 실행 계획 확인

```sql
EXPLAIN
SELECT ...;

EXPLAIN ANALYZE
SELECT ...;
```

`EXPLAIN ANALYZE`는 쿼리를 실제로 실행하여 예상 행 수와 실제 행 수, 실제 실행 시간을 함께 보여준다.

### 주요 특징

- `Seq Scan`, `Index Scan`, `Index Only Scan`, `Bitmap Index Scan`, `Bitmap Heap Scan` 등 다양한 접근 경로를 사용한다.
- Bitmap Scan은 여러 인덱스 조건을 결합하거나 비교적 많은 행을 가져올 때 유용하다.
- Nested Loop 내부의 반복 탐색 결과를 캐시하는 `Memoize` 노드를 사용할 수 있다.
- Hash Join의 해시 테이블이 메모리를 초과하면 여러 Batch로 나뉘며 임시 파일 사용이 발생할 수 있다.
- `work_mem`은 Sort와 Hash 같은 실행 노드별 메모리 한도에 영향을 준다.
- 통계 정보와 `ANALYZE` 결과가 조인 순서와 방식 선택에 큰 영향을 준다.
- 다수 테이블 조인에서는 탐색 공간이 커지며 설정에 따라 GEQO가 사용될 수 있다.
- 플래너 설정으로 특정 조인 방식을 비활성화할 수 있지만, 일반적으로 성능 진단 목적 외에는 강제 제어보다 통계와 인덱스를 개선하는 것이 우선이다.

### 실행 계획에서 볼 항목

```text
cost=시작비용..전체비용
rows=예상 행 수
actual time=실제 시작시간..전체시간
actual rows=실제 행 수
loops=노드 반복 실행 횟수
```

예상 `rows`와 실제 행 수의 차이가 크다면 통계 부족, 컬럼 간 상관관계, 데이터 편향 등을 의심해야 한다.

---

## 6.2 MySQL

MySQL은 비용 기반 최적화를 수행하며 테이블의 조인 순서와 접근 방식을 선택한다. 전통적으로 Nested Loop 계열이 중심이었지만 MySQL 8.0.18부터 Hash Join이 도입되었고, MySQL 8.0.20부터 기존 Block Nested Loop가 제거된 영역에서는 Hash Join이 사용된다.

### 실행 계획 확인

```sql
EXPLAIN
SELECT ...;

EXPLAIN FORMAT=TREE
SELECT ...;

EXPLAIN ANALYZE
SELECT ...;
```

`EXPLAIN ANALYZE`는 TREE 형식을 사용하며 실제 실행 시간과 실제 행 수를 확인할 수 있다.

### 주요 특징

- 인덱스 기반 Nested Loop Join이 핵심적인 조인 방식이다.
- 적용 가능한 조인 인덱스가 없는 동등 조인에서는 Hash Join이 선택될 수 있다.
- `EXPLAIN FORMAT=TREE`에서 Hash Join 사용 여부를 명확하게 확인할 수 있다.
- Batched Key Access(BKA)는 여러 키 탐색을 묶어 처리하고 조인 버퍼와 Multi-Range Read를 활용할 수 있다.
- 실행 계획의 `type` 값은 접근 효율을 판단하는 핵심 정보이다.

### 주요 접근 유형

```text
system / const / eq_ref / ref / range / index / ALL
```

일반적으로 `const`, `eq_ref`, `ref`, `range`는 비교적 효율적인 접근이며, `ALL`은 전체 테이블 스캔을 의미한다. 다만 전체 스캔 자체가 항상 잘못된 것은 아니며, 대량 결과를 읽는 쿼리에서는 인덱스보다 효율적일 수 있다.

### 실행 계획에서 볼 항목

- `possible_keys`: 사용 후보 인덱스
- `key`: 실제 선택된 인덱스
- `rows`: 예상 탐색 행 수
- `filtered`: 조건 통과 예상 비율
- `Extra`: 추가 실행 정보
- TREE 형식의 실제 조인 알고리즘과 조건

MySQL에서는 기본 표 형식의 `EXPLAIN`만으로 Hash Join 여부가 충분히 드러나지 않을 수 있으므로 TREE 형식을 함께 확인하는 것이 좋다.

---

## 6.3 Oracle Database

Oracle Database는 Cost-Based Optimizer(CBO)를 중심으로 실행 계획을 선택한다. Nested Loops, Hash Join, Sort Merge Join을 지원하며 통계 정보, 조인 순서, 접근 경로, 메모리, 병렬 실행 등을 종합적으로 평가한다.

### 실행 계획 확인

```sql
EXPLAIN PLAN FOR
SELECT ...;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);
```

실제 실행 통계를 포함하려면 다음과 같은 방식이 사용된다.

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ ...;

SELECT *
FROM TABLE(
    DBMS_XPLAN.DISPLAY_CURSOR(
        NULL,
        NULL,
        'ALLSTATS LAST'
    )
);
```

### 주요 특징

- 통계 기반의 CBO가 조인 순서와 조인 방식을 결정한다.
- Nested Loops는 작은 선행 결과와 인덱스 기반 후행 탐색에 적합하다.
- Hash Join은 대량 동등 조인과 병렬 실행에서 자주 활용된다.
- Sort Merge Join은 정렬된 입력이나 범위 조건에서 고려될 수 있다.
- 실행 계획에 `NESTED LOOPS`, `HASH JOIN`, `MERGE JOIN` 등이 표시된다.
- Partition Pruning, Bloom Filter, 병렬 실행 등 대규모 데이터 처리 기능이 강하다.
- 힌트를 통해 조인 순서나 방식을 제어할 수 있지만, 힌트는 실행 계획을 장기적으로 고정하는 위험이 있으므로 신중하게 사용해야 한다.
- SQL Plan Management를 통해 검증된 실행 계획을 Baseline으로 관리할 수 있다.

### 실행 계획에서 볼 항목

- `E-Rows`: 옵티마이저가 예상한 행 수
- `A-Rows`: 실제 처리한 행 수
- `Buffers`: 논리적 I/O
- `Reads`: 물리적 I/O
- `TempSpc`: 임시 영역 사용량
- `Starts`: 연산 시작 횟수

`E-Rows`와 `A-Rows`의 차이가 크다면 잘못된 카디널리티 추정으로 인해 부적절한 조인 순서나 조인 방식이 선택되었을 가능성이 있다.

---

## 6.4 Microsoft SQL Server

SQL Server의 비용 기반 옵티마이저는 Nested Loops, Hash Match, Merge Join을 주요 물리적 조인 연산자로 사용한다. 실행 계획은 그래픽 형태로 제공되며 각 연산자의 예상 비용, 예상 행 수, 실제 행 수, 메모리 사용 등을 확인할 수 있다.

### 실행 계획 확인

```sql
SET SHOWPLAN_XML ON;
```

또는 SQL Server Management Studio에서 다음 기능을 사용한다.

```text
Display Estimated Execution Plan
Include Actual Execution Plan
Live Query Statistics
```

### 주요 특징

- `Nested Loops`, `Hash Match`, `Merge Join` 연산자를 사용한다.
- `Index Seek`와 `Key Lookup` 조합이 자주 나타난다.
- 반환 행이 많을 때 Key Lookup이 반복되면 높은 비용이 발생할 수 있다.
- Hash Join과 Sort에는 Memory Grant가 할당되며 부족하면 TempDB Spill이 발생한다.
- Adaptive Join은 실행 중 Build 입력의 실제 행 수를 기준으로 Nested Loops와 Hash Join 중 하나를 선택할 수 있다.
- Cardinality Estimator의 추정 정확도가 조인 순서와 방식에 큰 영향을 준다.
- Query Store를 통해 실행 계획과 성능 변화를 추적하고 특정 계획을 강제할 수 있다.
- 병렬 실행에서는 Exchange 연산자가 추가되며 데이터 분배 비용도 확인해야 한다.

### 실행 계획에서 볼 항목

- Estimated Number of Rows
- Actual Number of Rows
- Actual Number of Rows for All Executions
- Number of Executions
- Memory Grant
- Spill Level
- Logical Reads
- Warnings
- Seek Predicate와 Residual Predicate

`Actual Number of Rows for All Executions`와 `Number of Executions`를 함께 보면 Nested Loops 내부 연산이 얼마나 반복되었는지 판단할 수 있다.

---

# 7. DBMS별 비교 요약

| 항목 | PostgreSQL | MySQL | Oracle Database | SQL Server |
|---|---|---|---|---|
| 기본 최적화 방식 | 비용 기반 | 비용 기반 | CBO | 비용 기반 |
| Nested Loop | 지원 | 핵심 방식 | 지원 | 지원 |
| Hash Join | 지원 | 8.0.18부터 지원 | 지원 | Hash Match로 지원 |
| Merge Join | 지원 | 일반적인 주요 조인 연산자로 노출되지 않음 | Sort Merge Join 지원 | 지원 |
| 실제 실행 분석 | `EXPLAIN ANALYZE` | `EXPLAIN ANALYZE` | `DBMS_XPLAN.DISPLAY_CURSOR` | Actual Execution Plan |
| 대표 인덱스 접근 | Index Scan, Bitmap Scan | ref, range, eq_ref | INDEX RANGE SCAN 등 | Index Seek, Key Lookup |
| 메모리 부족 시 | Temp 파일, Hash Batch 증가 | 내부 Temp 및 Hash 처리 비용 증가 | TEMP 사용 | TempDB Spill |
| 계획 안정화 기능 | 확장 기능 또는 설정 활용 | 힌트 및 옵티마이저 설정 | SQL Plan Baseline | Query Store Plan Forcing |
| 특이 기능 | Memoize, Bitmap Heap Scan | BKA, TREE 형식 계획 | 힌트, 파티션·병렬 기능 | Adaptive Join, Query Store |

> MySQL은 PostgreSQL·Oracle·SQL Server와 달리 Merge Join을 대표적인 일반 조인 알고리즘으로 제공하지 않으므로, 실행 계획 비교 시 Nested Loop 계열과 Hash Join을 중심으로 분석하는 것이 적절하다.

---

# 8. 실행 계획 비교 실습 방법

동일한 논리적 결과를 반환하는 쿼리를 대상으로 인덱스와 조회 범위를 변경하면서 실행 계획을 비교한다.

## 8.1 소량 조회

```sql
SELECT s.student_id,
       s.student_name,
       e.course_id
FROM student s
JOIN enrollment e
  ON e.student_id = s.student_id
WHERE s.student_id = 1001;
```

### 예상 관찰 결과

- `student`에서 극소수 행 조회
- `enrollment.student_id` 인덱스 사용
- Nested Loop 계열 선택 가능성 증가

## 8.2 대량 조회

```sql
SELECT s.student_id,
       s.student_name,
       e.course_id
FROM student s
JOIN enrollment e
  ON e.student_id = s.student_id;
```

### 예상 관찰 결과

- 양쪽 테이블의 많은 행 처리
- PostgreSQL, Oracle, SQL Server에서는 Hash Join 선택 가능성 증가
- MySQL에서도 적용 가능한 인덱스가 없는 동등 조인이라면 Hash Join 선택 가능

## 8.3 인덱스 추가 전후 비교

```sql
CREATE INDEX idx_enrollment_student_id
    ON enrollment(student_id);
```

인덱스 추가 전후로 다음 항목을 비교한다.

- 조인 방식 변화
- 전체 스캔과 인덱스 접근의 변화
- 예상 행 수와 실제 행 수
- 실행 시간
- 논리적·물리적 I/O
- Sort 또는 Hash의 메모리 사용
- 임시 디스크 Spill 여부
- 내부 노드 반복 횟수

---

# 9. 성능 개선 판단 기준

조인 성능 개선은 특정 조인 방식을 무조건 사용하도록 만드는 것이 아니라, 옵티마이저가 실제 데이터에 적합한 계획을 선택할 수 있도록 조건을 개선하는 작업이다.

우선적으로 확인할 사항은 다음과 같다.

1. **카디널리티 추정 오차**  
   예상 행 수와 실제 행 수의 차이가 크면 통계를 갱신하거나 데이터 분포와 컬럼 상관관계를 검토한다.

2. **조인 컬럼 인덱스**  
   소량 조회에서 내부 입력의 인덱스가 없으면 Nested Loop의 반복 비용이 커질 수 있다.

3. **복합 인덱스 순서**  
   조인 조건뿐 아니라 자주 사용하는 필터 조건을 함께 고려해 인덱스 컬럼 순서를 설계한다.

4. **불필요한 대량 조회**  
   조인 전에 필터링할 수 있도록 조건을 명확히 작성하고 필요한 컬럼만 조회한다.

5. **메모리와 Spill**  
   Hash와 Sort가 디스크로 Spill되는지 확인하고, 쿼리 구조와 메모리 설정을 함께 검토한다.

6. **반복 실행 횟수**  
   Nested Loop 내부 노드의 `loops`, `Starts`, `Number of Executions`가 과도하게 큰지 확인한다.

7. **통계 최신성**  
   대량 입력이나 데이터 분포 변경 후 통계가 오래되면 잘못된 조인 순서와 방식이 선택될 수 있다.

8. **강제 힌트의 사용**  
   힌트는 원인 분석과 단기 우회에 사용할 수 있지만 데이터 증가와 분포 변화에 취약하므로 최종 수단으로 사용한다.

---

# 10. 결론

Nested Loop Join은 소량 데이터와 인덱스 기반 탐색에 적합하고, Hash Join은 대량의 동등 조인에 유리하며, Merge Join은 양쪽 입력이 정렬되어 있거나 정렬 비용을 상쇄할 수 있는 대량 조인에서 효과적이다.

PostgreSQL, Oracle Database, SQL Server는 세 가지 주요 조인 방식을 모두 제공하지만, MySQL은 Nested Loop 계열과 Hash Join을 중심으로 실행 계획을 구성한다. 또한 PostgreSQL의 Bitmap Scan과 Memoize, MySQL의 BKA, Oracle의 SQL Plan Management와 병렬 처리, SQL Server의 Adaptive Join과 Query Store처럼 엔진별 고유 기능이 존재한다.

따라서 조인 성능을 개선할 때는 조인 알고리즘의 명칭만 확인하지 말고, 예상 행 수와 실제 행 수, 인덱스 접근 방식, 반복 실행 횟수, 메모리 사용량, 임시 디스크 Spill 여부를 함께 분석해야 한다.

---

# 참고 자료

- PostgreSQL Documentation 18, Planner/Optimizer
- PostgreSQL Documentation 18, Using EXPLAIN
- PostgreSQL Documentation 18, Query Planning
- MySQL 8.4 Reference Manual, Nested-Loop Join Algorithms
- MySQL 8.4 Reference Manual, Hash Join Optimization
- MySQL 8.4 Reference Manual, EXPLAIN Statement and EXPLAIN Output Format
- Oracle Database 26 Documentation, Joins
- Oracle Database Documentation, Generating and Displaying Execution Plans
- Microsoft Learn, Joins (SQL Server)
- Microsoft Learn, Logical and Physical Showplan Operator Reference
- Microsoft Learn, Intelligent Query Processing Details
