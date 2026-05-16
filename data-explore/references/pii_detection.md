---
name: pii_detection
description: PII and sensitive data column name patterns and value-level detection rules for banking/insurance contexts. Load this when performing the PII check phase before any profiling.
type: reference
---

# PII and Sensitive Data Detection Patterns

Check column names (case-insensitive substring match) against these patterns BEFORE running any profiling queries. Also scan sample values for value-level PII. Warn the user for any match and require explicit confirmation before profiling flagged columns.

## HIGH Risk: Always Warn — Require Explicit Confirmation

| Column Name Pattern | Likely Content | Regulatory Scope |
|---------------------|---------------|-----------------|
| `ssn`, `social_security`, `sin` | Social Security / Insurance Number | GLBA, CCPA, PIPEDA |
| `tax_id`, `tin`, `ein`, `itin` | Tax identification numbers | GLBA |
| `credit_card`, `card_number`, `card_num`, `pan` | Payment card number | PCI-DSS |
| `account_number`, `acct_number`, `acct_num`, `iban`, `bsb` | Bank account number | GLBA |
| `routing_number`, `sort_code`, `routing_nbr` | Bank routing number | GLBA |
| `passport`, `passport_number`, `passport_nbr` | Passport number | GDPR, CCPA |
| `drivers_license`, `dl_number`, `drv_lic`, `license_number` | Driver's license | CCPA |
| `biometric` | Biometric data | GDPR, BIPA |
| `genetic` | Genetic data | GDPR |

## MEDIUM Risk: Warn, Proceed With Care

| Column Name Pattern | Likely Content | Notes |
|--------------------|---------------|-------|
| `dob`, `date_of_birth`, `birth_date`, `birthdate`, `birth_dt` | Date of birth | Quasi-identifier |
| `first_name`, `fname`, `given_name` | First name | Low alone, high combined |
| `last_name`, `lname`, `surname`, `family_name` | Last name | Low alone, high combined |
| `full_name`, `customer_name`, `member_name`, `insured_name` | Full name | Medium risk |
| `email`, `email_address`, `email_addr` | Email address | GDPR, CAN-SPAM |
| `phone`, `telephone`, `mobile`, `cell_phone`, `phone_number` | Phone number | TCPA, GDPR |
| `address`, `street_address`, `addr_line`, `home_address` | Street address | GDPR, CCPA |
| `ip_address`, `ip_addr` | IP address | GDPR |
| `device_id`, `device_identifier` | Device ID | CCPA |
| `gender`, `sex` | Gender | Context-dependent |

## Insurance and Healthcare-Specific Risk (HIGH)

| Column Name Pattern | Likely Content | Regulatory Scope |
|--------------------|---------------|-----------------|
| `diagnosis`, `diagnosis_code`, `icd_code`, `icd10` | Medical diagnosis code | HIPAA, ADA |
| `procedure_code`, `cpt_code`, `procedure_cd` | Medical procedure | HIPAA |
| `npi`, `provider_npi`, `prescriber_npi` | National Provider Identifier | HIPAA |
| `medical_record`, `mrn`, `health_record` | Medical record | HIPAA |
| `drug`, `medication`, `rx`, `prescription` | Prescription information | HIPAA |
| `health_condition`, `condition`, `diagnosis_desc` | Health condition | HIPAA, GDPR |
| `disability` | Disability status | ADA, GDPR |
| `race`, `ethnicity`, `ethnic_group` | Race/ethnicity | GDPR special category |
| `religion`, `religious` | Religious belief | GDPR special category |
| `criminal`, `conviction`, `offense` | Criminal record | GDPR special category |

## Value-Level Detection (Scan Sample Rows)

For columns not caught by name patterns, run the following regex checks on sample values:

| PII Type | Pattern | Example Match |
|----------|---------|--------------|
| SSN (formatted) | `^\d{3}-\d{2}-\d{4}$` | `123-45-6789` |
| SSN (unformatted) | `^\d{9}$` on numeric columns | `123456789` |
| Email | Contains `@` and `.` | `user@domain.com` |
| US Phone | `^\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}$` | `555-123-4567` |
| Credit Card | `^\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}$` | `4111 1111 1111 1111` |
| IP Address | `^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$` | `192.168.1.1` |

## Warning Template

Output this warning when PII columns are detected:

```
WARNING: SENSITIVE DATA DETECTED

The following columns match PII/sensitive data patterns:

HIGH RISK (require explicit confirmation before profiling):
  - {column_name} → pattern: {pattern} | regulation: {scope}

MEDIUM RISK (proceed with care):
  - {column_name} → pattern: {pattern}

Before profiling sensitive columns:
1. Confirm authorization to access this data
2. Note that SQL query logs may capture values
3. Consider using hashed/masked versions for analysis

Proceed with profiling HIGH RISK columns? (y/n)
If 'n', these columns will be excluded from profiling.
```

## PII-Safe Profiling Approach

For confirmed HIGH RISK columns, profile using hash-based counting only. Never include sample values or top-10 value frequency for HIGH RISK columns.

- Snowflake: `COUNT(DISTINCT MD5({column}::STRING))`
- Redshift: `APPROXIMATE COUNT(DISTINCT MD5({column}))`
- BigQuery: `COUNT(DISTINCT TO_HEX(MD5(CAST({column} AS STRING))))`
- Generic: `COUNT(DISTINCT {column})` — do NOT display the values, only the count
