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
        -- Fact table surrogate key
        {{ dbt_utils.generate_surrogate_key(['crime_id']) }} AS incident_key,
        
        -- Natural key
        crimes.crime_id,
        
        -- Foreign keys to dimensions
        TO_CHAR(crimes.incident_date, 'YYYYMMDD')::INTEGER AS incident_date_key,
        crime_types.crime_type_key,
        locations.location_key,
        cases.case_key,
        
        -- Degenerate dimensions (attributes that don't warrant their own dimension)
        crimes.case_number,
        crimes.block_address,
        
        -- Date/time stamps
        crimes.incident_datetime,
        crimes.incident_date,
        crimes.incident_year,
        
        -- Measures and facts
        1                                           AS incident_count,
        
        -- Additive measures for different analysis needs
        CASE WHEN crimes.was_arrest_made = TRUE THEN 1 ELSE 0 END AS arrest_count,
        CASE WHEN crimes.is_domestic_violence = TRUE THEN 1 ELSE 0 END AS domestic_violence_count,
        
        -- Semi-additive measures (additive across some dimensions)
        crimes.latitude,
        crimes.longitude,
        
        -- Audit fields
        crimes.last_updated_at,
        CURRENT_TIMESTAMP                           AS fact_created_at

    FROM {{ ref('stg_chicago_crimes') }} AS crimes
    
    -- Join to dimension tables to get surrogate keys
    LEFT JOIN {{ ref('dim_crime_type') }} AS crime_types
        ON crimes.iucr_code = crime_types.iucr_code
    
    LEFT JOIN {{ ref('dim_location') }} AS locations
        ON {{ dbt_utils.generate_surrogate_key([
            'crimes.beat', 'crimes.district', 'crimes.ward', 
            'crimes.community_area', 'crimes.location_description'
        ]) }} = locations.location_key
    
    LEFT JOIN {{ ref('dim_case') }} AS cases
        ON crimes.case_number = cases.case_number
    
    -- Data quality filter
    WHERE crimes.data_quality_flag = 'VALID'
)

SELECT * FROM fact_data
ORDER BY incident_datetime DESC