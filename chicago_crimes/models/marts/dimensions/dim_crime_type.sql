{{
  config(
    materialized='table'
  )
}}

WITH crime_type_counts AS (
  -- Count occurrences of each fbi_code per business key combination
  SELECT 
    iucr_code,
    primary_crime_type,
    crime_description,
    fbi_code,
    COUNT(*) as fbi_code_count
  FROM {{ ref('stg_chicago_crimes') }}
  WHERE iucr_code IS NOT NULL
    AND primary_crime_type IS NOT NULL
    AND crime_description IS NOT NULL
  GROUP BY iucr_code, primary_crime_type, crime_description, fbi_code
),

most_common_fbi AS (
  -- Get the most frequent fbi_code for each business key combination
  SELECT 
    iucr_code,
    primary_crime_type,
    crime_description,
    fbi_code,
    ROW_NUMBER() OVER (
      PARTITION BY iucr_code, primary_crime_type, crime_description 
      ORDER BY fbi_code_count DESC, fbi_code
    ) as rn
  FROM crime_type_counts
),

crime_types AS (
  -- Keep only the most common fbi_code (rn = 1)
  SELECT 
    iucr_code,
    primary_crime_type,
    crime_description,
    fbi_code
  FROM most_common_fbi
  WHERE rn = 1
),

crime_type_dimension AS (
  SELECT
    -- Use the business key combination as the basis for surrogate key
    {{ dbt_utils.generate_surrogate_key([
        'iucr_code',
        'primary_crime_type', 
        'crime_description'
    ]) }} AS crime_type_key,
    
    -- Natural keys
    iucr_code,
    fbi_code,
    
    -- Descriptive attributes
    primary_crime_type,
    crime_description,
    
    -- Business categorization
    CASE 
      WHEN primary_crime_type IN ('HOMICIDE', 'ASSAULT', 'BATTERY', 'CRIMINAL SEXUAL ASSAULT')
      THEN 'Violent Crime'
      WHEN primary_crime_type IN ('BURGLARY', 'THEFT', 'MOTOR VEHICLE THEFT', 'ROBBERY')
      THEN 'Property Crime'
      WHEN primary_crime_type IN ('NARCOTICS', 'OTHER NARCOTIC VIOLATION')
      THEN 'Drug Related'
      WHEN primary_crime_type IN ('PUBLIC PEACE VIOLATION', 'DISORDERLY CONDUCT')
      THEN 'Public Order'
      ELSE 'Other'
    END AS crime_category,
    
    -- Severity classification
    CASE 
      WHEN primary_crime_type IN ('HOMICIDE', 'CRIMINAL SEXUAL ASSAULT')
      THEN 'High Severity'
      WHEN primary_crime_type IN ('ASSAULT', 'BATTERY', 'ROBBERY', 'BURGLARY')
      THEN 'Medium Severity'
      ELSE 'Low Severity'
    END AS severity_level,
    
    -- Metadata
    CURRENT_TIMESTAMP AS created_at
  FROM crime_types
)

SELECT * FROM crime_type_dimension
ORDER BY primary_crime_type, crime_description