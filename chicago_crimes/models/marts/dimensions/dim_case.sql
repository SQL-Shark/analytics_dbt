{{
  config(
    materialized='table'
  )
}}

WITH cases AS (
    SELECT DISTINCT
        case_number,
        was_arrest_made,
        is_domestic_violence,
        data_quality_flag
    FROM {{ ref('stg_chicago_crimes') }}
    WHERE case_number IS NOT NULL
),

case_dimension AS (
    SELECT
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['case_number']) }} AS case_key,
        
        -- Natural key
        case_number,
        
        -- Case attributes
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
        END                                         AS case_classification,
        
        -- Data quality
        data_quality_flag,
        CASE 
            WHEN data_quality_flag = 'VALID' THEN TRUE 
            ELSE FALSE 
        END                                         AS is_high_quality,
        
        CURRENT_TIMESTAMP                           AS created_at

    FROM cases
)

SELECT * FROM case_dimension
ORDER BY case_number