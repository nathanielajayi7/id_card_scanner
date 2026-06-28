# OCR Instruction Set Validation Results

This report outlines the performance of the extraction instructions against the mock dataset.

## 1. Overall Metrics

| Metric | Value |
| --- | --- |
| Total Documents Tested | 2 |
| Perfect Documents (All fields extracted correctly) | 1 |
| Overall Exact Match Accuracy | 87.50% |
| Overall Character Error Rate (CER) | 12.50% |

## 2. Field-Level Accuracy

| Field Name | Exact Match Accuracy |
| --- | --- |
| First Name | 100.00% |
| Gender | 100.00% |
| Given Names | 100.00% |
| Last Name | 100.00% |
| Middle Name | 100.00% |
| NIN Number | 0.00% |
| Passport Number | 100.00% |
| Surname | 100.00% |

## 3. Error Analysis

### Case: test_nin_slip_001
| Field | Expected | Actual | CER |
| --- | --- | --- | --- |
| NIN Number | `12345678901` | `` | 100.00% |

