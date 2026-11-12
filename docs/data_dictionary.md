# Data dictionary: `pfie20142020.csv`

Encoding: UTF-8 CSV with a header row. 9 columns, 1,779 rows, 1,437 unique `incidentid` values.

| Column | Type | Description | Values |
|---|---|---|---|
| `officerid` | integer | Unique officer identifier. Whole numbers from 1 upward, assigned in order of incident `date`. Ties on the same date go by `incidentid`, then by original file order. One row is one injured officer. | 1 to 1,779, unique. |
| `incidentid` | integer | GVA incident identifier. | Repeats across rows (see below). |
| `date` | date | Date of the incident. | `YYYY-MM-DD`, 2014-01-02 to 2020-12-29. |
| `statuslabel` | string | Ultimate outcome for the officer. An officer first reported as injured who later died is coded Fatal. | `Fatal` (286 rows), `Nonfatal` (1,493 rows). |
| `state` | string | State of the incident. | 50 states and DC (51 values). |
| `latitude` | number | Latitude of the incident, decimal degrees. | 19.03 to 65.18. No missing values. |
| `longitude` | number | Longitude of the incident, decimal degrees. | -165.59 to -69.39. No missing values. |
| `agencytypelabel` | string | Type of the officer's agency. | `Local` (1,191), `Sheriff` (454), `State` (119), `Special` (15). |
| `sources` | string | Comma-separated URLs to news or agency reports on the incident. | Up to 12 URLs. One row is empty. |

## Rows and incidents

Each row is one injured officer. An incident with more than one officer shot has more than one row. 342 rows repeat an earlier `incidentid`. 223 rows match another row on every column except `officerid`, because the officers share the same incident details. 60 incident IDs have both a Fatal and a Nonfatal row.

Rows are not sorted by `officerid`. Sort by it to see the officers in date order.

An `officerid` is permanent once assigned. New records in later versions get the next unused numbers and never renumber earlier officers. Rows that match on every other column are interchangeable, so the number carries no meaning beyond identifying the row.

Count unique `incidentid` values to count incidents. Count rows, or unique `officerid` values, to count officers.

## Notes

- `statuslabel` and `agencytypelabel` come from the project's recoding of GVA fields. The cleaning guide documents the coding rules for `Status2` and `agencytype`, which these labels reflect.
- `Special` agencies include university, school, park, housing authority, transit, and tribal police.
- No row in `pfie20142020.csv` holds a state centroid as its coordinates.
