# 인출 순서 최적화 알고리즘 설계

> 연금나침반 핵심 엔진

---

## 1. 문제 정의

### 입력 (Input)
```
{
  "pension_savings": 100000000,    // 연금저축 잔액 (원)
  "pension_savings_deducted": 80000000,  // 세액공제 받은 금액
  "irp_balance": 50000000,         // IRP 잔액 (원)
  "irp_retirement_portion": 40000000,   // IRP 중 퇴직금 이전분
  "isa_maturity": 30000000,        // ISA 만기 예정액 (원)
  "isa_profit": 5000000,           // ISA 수익분 (비과세 적용)
  "current_age": 58,               // 현재 나이
  "target_annual_withdrawal": 24000000,  // 연간 목표 인출액 (원)
  "simulation_years": 20,          // 시뮬레이션 기간 (년)
  "other_income": 0                // 기타 종합소득 (원)
}
```

### 출력 (Output)
```
{
  "optimal_sequence": [
    {"year": 1, "source": "ISA", "amount": 24000000, "tax": 0},
    {"year": 2, "source": "PENSION_NON_DEDUCTED", "amount": 20000000, "tax": 0},
    ...
  ],
  "total_tax_optimal": 15000000,
  "total_tax_baseline": 22000000,
  "savings": 7000000,
  "savings_rate": 31.8
}
```

---

## 2. 자금 풀 (Fund Pools) 분류

인출 가능한 자금을 세금 특성별로 분류:

| Pool ID | 명칭 | 세율 | 우선순위 |
|---|---|---|---|
| `ISA_PROFIT` | ISA 수익분 | 0% (비과세 한도 내) | 1 |
| `ISA_PRINCIPAL` | ISA 원금 | 0% | 2 |
| `PENSION_NON_DEDUCTED` | 연금저축 비공제분 | 0% | 3 |
| `PENSION_DEDUCTED` | 연금저축 공제분 | 3.3~5.5% | 4 |
| `IRP_SELF` | IRP 자기납입분 | 3.3~5.5% | 5 |
| `IRP_RETIREMENT` | IRP 퇴직금분 | 퇴직소득세×70% | 6 |

---

## 3. 핵심 알고리즘

### 3.1 Greedy 기반 최적화

```python
def optimize_withdrawal(input_data: dict) -> dict:
    """
    Greedy 알고리즘으로 인출 순서 최적화
    
    원칙: 세율이 낮은 풀부터 소진
    """
    pools = initialize_pools(input_data)
    schedule = []
    
    for year in range(1, input_data["simulation_years"] + 1):
        age = input_data["current_age"] + year - 1
        target = input_data["target_annual_withdrawal"]
        remaining = target
        year_withdrawals = []
        
        # 세율 순으로 정렬된 풀에서 순차 인출
        for pool in sorted(pools, key=lambda p: p.tax_rate(age)):
            if remaining <= 0:
                break
            
            withdrawal = min(remaining, pool.balance)
            if withdrawal > 0:
                tax = pool.calculate_tax(withdrawal, age)
                pool.balance -= withdrawal
                remaining -= withdrawal
                
                year_withdrawals.append({
                    "source": pool.id,
                    "amount": withdrawal,
                    "tax": tax
                })
        
        schedule.append({
            "year": year,
            "age": age,
            "withdrawals": year_withdrawals,
            "total_tax": sum(w["tax"] for w in year_withdrawals)
        })
    
    return {
        "schedule": schedule,
        "total_tax": sum(y["total_tax"] for y in schedule)
    }
```

### 3.2 연간 1,500만원 한도 고려

```python
def apply_annual_limit(withdrawals: list, limit: int = 15000000) -> list:
    """
    분리과세 한도(1,500만원) 초과 시 종합과세 전환 계산
    
    종합과세 시 다른 소득과 합산되어 누진세율 적용
    → 대부분의 경우 분리과세가 유리
    → 1,500만원 이하로 유지하는 것이 최적
    """
    pension_withdrawal = sum(
        w["amount"] for w in withdrawals 
        if w["source"] in ["PENSION_DEDUCTED", "IRP_SELF"]
    )
    
    if pension_withdrawal > limit:
        # 초과분에 대해 종합과세 vs 분리과세 비교 필요
        return recalculate_with_comprehensive_tax(withdrawals)
    
    return withdrawals
```

### 3.3 ISA 만기 이전 최적화

```python
def optimize_isa_transfer(isa_amount: int, income_level: str) -> dict:
    """
    ISA 만기 후 연금저축 이전 세액공제 계산
    
    조건: 만기 후 60일 내 이전
    혜택: 이전액의 10% 세액공제 (최대 300만원)
    """
    credit_base = min(isa_amount * 0.1, 3_000_000)
    
    if income_level == "high":
        credit = credit_base * 0.132
    else:
        credit = credit_base * 0.165
    
    return {
        "transfer_amount": isa_amount,
        "credit_base": credit_base,
        "tax_credit": int(credit),
        "recommendation": "ISA 만기 후 60일 내 연금저축 이전 권장"
    }
```

---

## 4. 비교 시나리오 (Baseline)

최적화 효과를 보여주기 위해 "비최적" 시나리오도 계산:

### 4.1 Baseline: 단순 균등 인출

```python
def baseline_equal_withdrawal(input_data: dict) -> dict:
    """
    모든 계좌에서 비례 인출 (비최적)
    """
    total_balance = (
        input_data["pension_savings"] + 
        input_data["irp_balance"] + 
        input_data["isa_maturity"]
    )
    
    pension_ratio = input_data["pension_savings"] / total_balance
    irp_ratio = input_data["irp_balance"] / total_balance
    isa_ratio = input_data["isa_maturity"] / total_balance
    
    # 각 계좌에서 비례하여 인출 → 세금 비효율
    ...
```

### 4.2 Baseline: 연금저축 먼저

```python
def baseline_pension_first(input_data: dict) -> dict:
    """
    연금저축부터 소진 (흔한 실수)
    → 세액공제분 먼저 인출 → 5.5% 과세 먼저 발생
    """
    ...
```

---

## 5. 복잡한 케이스 처리

### 5.1 퇴직소득세 계산 (IRP 퇴직금분)

```python
def calc_retirement_income_tax(
    retirement_amount: int,
    years_of_service: int,
    is_pension: bool = True
) -> int:
    """
    퇴직소득세 계산
    
    연금 수령 시 30% 감면 적용
    """
    # 근속연수 공제
    if years_of_service <= 5:
        deduction = 1_000_000 * years_of_service
    elif years_of_service <= 10:
        deduction = 5_000_000 + 2_000_000 * (years_of_service - 5)
    elif years_of_service <= 20:
        deduction = 15_000_000 + 2_500_000 * (years_of_service - 10)
    else:
        deduction = 40_000_000 + 3_000_000 * (years_of_service - 20)
    
    # 환산급여 계산
    taxable = max(0, retirement_amount - deduction)
    converted = (taxable * 12) / years_of_service
    
    # 세율 적용 (퇴직소득 세율표)
    tax = apply_retirement_tax_bracket(converted) * years_of_service / 12
    
    # 연금 수령 시 30% 감면
    if is_pension:
        tax = tax * 0.7
    
    return int(tax)
```

### 5.2 건강보험료 임계점

```python
def check_health_insurance_impact(annual_pension: int) -> dict:
    """
    연금소득이 건강보험료에 미치는 영향 체크
    
    연 2,000만원 이상 시 지역가입자 전환 가능성
    """
    threshold = 20_000_000
    
    if annual_pension >= threshold:
        return {
            "warning": True,
            "message": "연 2,000만원 이상 연금소득 시 건강보험료 부과 대상",
            "recommendation": "1,500만원 이하로 분산 인출 권장"
        }
    
    return {"warning": False}
```

---

## 6. 시각화 데이터 생성

### 6.1 연도별 누적 차트 데이터

```python
def generate_chart_data(optimal: dict, baseline: dict) -> dict:
    """
    fl_chart용 데이터 생성
    """
    return {
        "x_labels": [f"{y}년차" for y in range(1, len(optimal["schedule"]) + 1)],
        "optimal_cumulative_tax": cumulative_sum([y["total_tax"] for y in optimal["schedule"]]),
        "baseline_cumulative_tax": cumulative_sum([y["total_tax"] for y in baseline["schedule"]]),
        "savings_by_year": [
            baseline["schedule"][i]["total_tax"] - optimal["schedule"][i]["total_tax"]
            for i in range(len(optimal["schedule"]))
        ]
    }
```

### 6.2 인출 구성 파이 차트

```python
def generate_pie_data(year_data: dict) -> list:
    """
    특정 연도의 인출 구성 파이 차트
    """
    return [
        {"label": source_to_korean(w["source"]), "value": w["amount"]}
        for w in year_data["withdrawals"]
    ]
```

---

## 7. 테스트 케이스

### TC1: 기본 시나리오
```python
input_basic = {
    "pension_savings": 100_000_000,
    "pension_savings_deducted": 80_000_000,
    "irp_balance": 50_000_000,
    "irp_retirement_portion": 40_000_000,
    "isa_maturity": 30_000_000,
    "isa_profit": 5_000_000,
    "current_age": 58,
    "target_annual_withdrawal": 24_000_000,
    "simulation_years": 20
}
# 예상: ISA → 비공제분 → 공제분 순으로 인출
# 예상 절감: 약 500만원 (20년 누적)
```

### TC2: 고액 자산가
```python
input_high = {
    "pension_savings": 500_000_000,
    "pension_savings_deducted": 400_000_000,
    "irp_balance": 300_000_000,
    "irp_retirement_portion": 250_000_000,
    "isa_maturity": 100_000_000,
    "current_age": 55,
    "target_annual_withdrawal": 60_000_000,
    "simulation_years": 30
}
# 주의: 연 1,500만원 한도 초과 시 종합과세 검토 필요
```

### TC3: ISA 만기 직전
```python
input_isa = {
    "pension_savings": 50_000_000,
    "isa_maturity": 40_000_000,
    "isa_days_to_maturity": 30,
    "current_age": 50
}
# 핵심: ISA 만기 후 연금저축 이전 세액공제 안내
```

---

## 8. 구현 우선순위

### Phase 1 (MVP)
1. ✅ 기본 Greedy 알고리즘
2. ✅ 연금소득세 계산 (나이별 세율)
3. ✅ ISA 비과세 처리
4. ✅ 최적 vs Baseline 비교

### Phase 2
1. ⬜ 퇴직소득세 정밀 계산
2. ⬜ 종합과세 vs 분리과세 분기점 계산
3. ⬜ 건강보험료 영향 경고

### Phase 3
1. ⬜ 몬테카를로 시뮬레이션 (수익률 변동)
2. ⬜ 목표 기반 역산 (필요 자산 계산)
