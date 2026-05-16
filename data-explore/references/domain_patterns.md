---
name: domain_patterns
description: Banking and insurance domain column name heuristics, known status code patterns, and business meaning inference rules. Load this during the Domain Inference phase.
type: reference
---

# Banking and Insurance Domain Patterns

Use these patterns to infer business meaning from column names and sample values. Always generate clarifying questions for ambiguous cases rather than asserting meaning without confirmation.

## Column Name → Business Meaning Heuristics

### ID / Key Columns

| Column Pattern | Inferred Meaning |
|----------------|-----------------|
| `policy_id`, `pol_id`, `policy_nbr`, `pol_no` | Insurance policy identifier (expect unique per policy) |
| `claim_id`, `clm_id`, `claim_nbr`, `clm_no` | Insurance claim identifier |
| `customer_id`, `cust_id`, `mbr_id`, `member_id`, `insured_id` | Customer / policyholder / member identifier |
| `account_id`, `acct_id`, `acct_nbr`, `acct_no` | Bank account identifier |
| `transaction_id`, `txn_id`, `trans_id`, `trxn_id` | Financial transaction identifier |
| `agent_id`, `broker_id`, `producer_id`, `advisor_id` | Distribution channel / agent identifier |
| `risk_id`, `exposure_id`, `location_id` | Risk unit identifier (P&C specific) |
| `coverage_id`, `cov_id` | Coverage/endorsement identifier |
| `quote_id`, `application_id`, `app_id` | Pre-policy stage identifier |

### Date Columns

| Column Pattern | Inferred Meaning | Notes |
|----------------|-----------------|-------|
| `effective_date`, `eff_dt`, `eff_date` | Business effective date (when record becomes active) | Expect <= expiry_date |
| `expiry_date`, `exp_dt`, `term_date`, `cancellation_date` | When record/policy expires or terminates | Can be future-dated for active policies |
| `inception_date`, `incep_dt`, `policy_start_date`, `policy_start` | Original policy start date | Should not change on renewal |
| `as_of_date`, `asof_date`, `snapshot_date`, `report_date` | Reporting snapshot date | Used in SCD Type 2 / versioned tables |
| `booking_date`, `posted_date`, `entry_date` | Date transaction was booked in system | Often system-generated |
| `settlement_date`, `value_date`, `cleared_date` | Financial settlement / clearing date | May differ from booking_date |
| `loss_date`, `occurrence_date`, `accident_date`, `incident_date` | Date loss/incident occurred | May be before report_date |
| `report_date`, `reported_date`, `fnol_date` | Date claim was first reported (FNOL) | Should be >= loss_date |
| `close_date`, `closed_dt`, `closure_date` | Date claim was closed | Should be >= loss_date |
| `load_date`, `etl_date`, `created_at`, `insert_dt` | System load / audit date | Technical, not business |
| `updated_at`, `modified_dt`, `last_updated` | Last record modification | Technical audit column |
| `renewal_date`, `next_renewal_date` | Next policy renewal date | Used in retention analysis |

### Amount Columns

| Column Pattern | Inferred Business Meaning | Expected Sign |
|----------------|--------------------------|--------------|
| `premium`, `written_premium`, `earned_premium`, `gwp`, `nwp` | Insurance premium | Positive (negative = return premium, flag but may be valid) |
| `claim_amount`, `paid_amount`, `total_paid`, `clm_amt` | Claim payment amount | Non-negative |
| `incurred_amount`, `total_incurred`, `ultimate_loss` | Total expected claim cost | Non-negative |
| `reserve_amount`, `case_reserve`, `outstanding_reserve` | Actuarial reserve | Non-negative |
| `ibnr`, `ibner` | Incurred But Not Reported / Enough Reported reserve | Can be negative (adjustment) |
| `face_amount`, `face_value`, `sum_insured`, `coverage_amount` | Policy coverage limit | Positive |
| `deductible`, `excess`, `retention` | Policyholder deductible | Non-negative |
| `commission`, `commission_amount`, `brokerage` | Agent/broker commission | Non-negative |
| `balance`, `outstanding_balance`, `current_balance` | Account balance | Can be negative (credit balance) |
| `transaction_amount`, `txn_amt` | Transaction value | Can be positive or negative |
| `limit`, `coverage_limit`, `policy_limit`, `aggregate_limit` | Maximum coverage | Positive |
| `reinsurance_amount`, `ri_amount`, `ceded_amount` | Reinsurance recoverable | Non-negative |

### Status / Flag Columns

| Column Pattern | Typical Values | Interpretation |
|----------------|---------------|----------------|
| `policy_status`, `pol_status`, `policy_stat` | Numeric codes or text | See Status Codes section |
| `claim_status`, `clm_status` | O/C/R/D or numeric | Open/Closed/Reopened/Denied |
| `is_active`, `active_flag`, `active_ind` | 0/1, Y/N, T/F | Boolean active indicator |
| `is_deleted`, `deleted_flag`, `del_ind` | 0/1, Y/N | Soft delete — filter out by default |
| `is_cancelled`, `cancelled_flag`, `cancel_ind` | 0/1, Y/N | Cancellation flag |
| `transaction_type`, `txn_type`, `trans_type` | D/C, P/R, codes | Debit/Credit, Premium/Refund |
| `coverage_type`, `cov_type`, `coverage_cd` | Text or code | Type of coverage (auto, fire, life) |
| `lob`, `line_of_business`, `product_line` | Text or code | Product line (Auto, Property, Life, Health) |
| `peril`, `peril_code`, `cause_of_loss` | Text or code | Cause of loss (fire, flood, theft) |
| `channel`, `distribution_channel`, `sales_channel` | Text | How policy was sold (direct, broker, agent) |
| `tier`, `risk_tier`, `rate_tier` | Numeric or text | Underwriting risk tier |

### Geographic Columns

| Column Pattern | Expected Format | Notes |
|----------------|----------------|-------|
| `state`, `state_cd`, `state_code` | 2-char US abbreviation | Flag if length != 2 |
| `zip`, `zip_code`, `postal_code` | 5-digit string | Flag if not zero-padded |
| `country`, `country_cd`, `country_code` | ISO 3166-1 alpha-2 | Flag if length != 2 |
| `territory`, `territory_cd`, `rating_territory` | Company-specific code | Varies by insurer |
| `region`, `market_region` | Business grouping | Varies by organization |

## Known Status Code Patterns

When a status column has numeric or single-char values and no data dictionary is available, use these as starting defaults — always generate clarifying questions to confirm.

### Insurance Policy Status (common numeric scheme)
```
1 = Active / In Force
2 = Pending / Application
3 = Issued, Not Yet Effective
4 = Lapsed
5 = Surrendered / Voluntarily Cancelled
6 = Expired
7 = Non-Renewed
8 = Reinstated
9 = Cancelled (involuntary)
```

### Insurance Claim Status (common char scheme)
```
O = Open
C = Closed
R = Reopened
D = Denied
W = Withdrawn
P = Pending / Under Review
```

### Transaction Types
```
P = Premium
E = Endorsement / Mid-term change
R = Refund / Return Premium
C = Cancellation
F = Fee
D = Dividend
```

## Domain Red Flags

Flag these when detected and generate a clarifying question:

- `premium` with negative values → may be return premium (legitimate) or error
- `claim_amount > face_amount` on same policy → possible error or subrogation
- `effective_date > expiry_date` → always an error
- `close_date < loss_date` → always an error
- `report_date < loss_date` → always an error
- `state_code` values other than 2-char → format issue
- Date columns stored as VARCHAR → cast needed, check format consistency
- Status columns with undocumented values → generate clarifying question
- `is_deleted = 1` rows in base tables → confirm these should be excluded from analysis
