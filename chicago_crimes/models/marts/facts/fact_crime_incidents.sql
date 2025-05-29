{{
  config(
    materialized='table',
    indexes=[
      {'columns': ['incident_date_key', 'crime_type_key']},
      {'columns': ['location_key']},
      {'columns': ['incident_datetime']}
    ]
  )
}}

WITH fact_data AS (
  SELECT
    -- Simple surrogate key since crime_id should be unique
    {{ dbt_utils.generate_surrogate_key(['crimes.crime_id']) }} AS incident_key,
    
    -- Natural key
    crimes.crime_id,
    
    -- Foreign keys to dimensions
    TO_CHAR(crimes.incident_date, 'YYYYMMDD')::INTEGER AS incident_date_key,
    crime_types.crime_type_key,
    locations.location_key,
    cases.case_key,
    
    -- Degenerate dimensions
    crimes.case_number,
    crimes.block_address,
    
    -- Date/time stamps
    crimes.incident_datetime,
    crimes.incident_date,
    crimes.incident_year,
    
    -- Measures and facts
    1 AS incident_count,
    
    -- Additive measures
    CASE WHEN crimes.was_arrest_made = TRUE THEN 1 ELSE 0 END AS arrest_count,
    CASE WHEN crimes.is_domestic_violence = TRUE THEN 1 ELSE 0 END AS domestic_violence_count,
    
    -- Semi-additive measures
    crimes.latitude,
    crimes.longitude,
    
    -- Audit fields
    crimes.last_updated_at,
    CURRENT_TIMESTAMP AS fact_created_at
    
  FROM {{ ref('stg_chicago_crimes') }} AS crimes
  
  -- Join to dimension tables to get surrogate keys
  LEFT JOIN (
    SELECT DISTINCT 
      iucr_code, primary_crime_type, crime_description, crime_type_key
    FROM {{ ref('dim_crime_type') }}
  ) AS crime_types
    ON crimes.iucr_code = crime_types.iucr_code
    AND crimes.primary_crime_type = crime_types.primary_crime_type
    AND crimes.crime_description = crime_types.crime_description
    
  LEFT JOIN (
    SELECT DISTINCT 
      beat, district, ward, community_area, location_description, 
      latitude, longitude, location_key
    FROM {{ ref('dim_location') }}
  ) AS locations
    ON COALESCE(crimes.beat::text, '-1') = locations.beat
    AND COALESCE(crimes.district::text, '-1') = locations.district
    AND COALESCE(crimes.ward::text, '-1') = locations.ward
    AND COALESCE(crimes.community_area::text, '-1') = locations.community_area
    AND COALESCE(crimes.location_description, 'Unknown') = locations.location_description
    AND COALESCE(crimes.latitude, 0) = COALESCE(locations.latitude, 0)
    AND COALESCE(crimes.longitude, 0) = COALESCE(locations.longitude, 0)
    
  -- JOIN ON CRIME_ID, NOT CASE_NUMBER!
  LEFT JOIN (
    SELECT DISTINCT 
      crime_id, case_key
    FROM {{ ref('dim_case') }}
  ) AS cases
    ON crimes.crime_id = cases.crime_id
    
  -- Data quality filter
  WHERE crimes.data_quality_flag = 'VALID'
)

SELECT * FROM fact_data
ORDER BY incident_datetime DESC