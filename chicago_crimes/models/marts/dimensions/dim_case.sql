{{
  config(
    materialized='table'
  )
}}

WITH cases AS (
  SELECT DISTINCT
    crime_id,
    case_number,
    was_arrest_made,
    is_domestic_violence,
    data_quality_flag
  FROM {{ ref('stg_chicago_crimes') }}
  WHERE crime_id IS NOT NULL
),

case_dimension AS (
  SELECT
    -- Use crime_id as the basis for case_key (1:1 with incidents)
    {{ dbt_utils.generate_surrogate_key(['crime_id']) }} AS case_key,
    
    -- Natural keys
    crime_id,
    case_number,
    
    -- Case attributes (incident-level)
    was_arrest_made,
    is_domestic_violence,
    
    -- Combined flags for easier analysis
    CASE 
      WHEN was_arrest_made = TRUE AND is_domestic_violence = TRUE
      THEN 'Domestic with Arrest'
      WHEN was_arrest_made = TRUE AND is_domestic_violence = FALSE
      THEN 'Non-Domestic with Arrest'
      WHEN was_arrest_made = FALSE AND is_domestic_violence = TRUE
      THEN 'Domestic without Arrest'
      WHEN was_arrest_made = FALSE AND is_domestic_violence = FALSE
      THEN 'Non-Domestic without Arrest'
      ELSE 'Unknown'
    END AS case_classification,
    
    -- Data quality
    data_quality_flag,
    CASE WHEN data_quality_flag = 'VALID' THEN TRUE ELSE FALSE END AS is_high_quality,
    
    CURRENT_TIMESTAMP AS created_at
  FROM cases
)


SELECT * FROM case_dimension
ORDER BY case_number