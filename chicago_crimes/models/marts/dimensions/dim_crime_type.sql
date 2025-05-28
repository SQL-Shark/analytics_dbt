{{
  config(
    materialized='table'
  )
}}

WITH crime_types AS (
  SELECT DISTINCT
    iucr_code,
    primary_crime_type,
    crime_description,
    fbi_code
  FROM {{ ref('stg_chicago_crimes') }}
  WHERE iucr_code IS NOT NULL
    AND primary_crime_type IS NOT NULL
    AND crime_description IS NOT NULL
),

crime_type_dimension AS (
  SELECT
    -- Use ROW_NUMBER to ensure unique keys
    ROW_NUMBER() OVER (ORDER BY iucr_code, primary_crime_type, crime_description) AS crime_type_key,
    
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