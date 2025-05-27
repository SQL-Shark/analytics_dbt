{{
  config(
    materialized='table'
  )
}}

WITH locations AS (
    SELECT DISTINCT
        beat,
        district,
        ward,
        community_area,
        location_description,
        -- Handle nulls in geographic coordinates
        COALESCE(latitude, 0)                       AS latitude,
        COALESCE(longitude, 0)                      AS longitude,
        COALESCE(x_coordinate, 0)                   AS x_coordinate,
        COALESCE(y_coordinate, 0)                   AS y_coordinate
    FROM {{ ref('stg_chicago_crimes') }}
),

location_dimension AS (
    SELECT
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key([
            'beat', 'district', 'ward', 'community_area', 'location_description'
        ]) }}                                       AS location_key,
        
        -- Administrative geography
        beat,
        district,
        ward,
        community_area,
        
        -- Location description
        COALESCE(location_description, 'Unknown')   AS location_description,
        
        -- Location categories
        CASE 
            WHEN location_description ILIKE '%STREET%' OR location_description ILIKE '%SIDEWALK%' 
            THEN 'Street/Public Area'
            WHEN location_description ILIKE '%RESIDENCE%' OR location_description ILIKE '%HOUSE%' OR location_description ILIKE '%APARTMENT%'
            THEN 'Residential'
            WHEN location_description ILIKE '%STORE%' OR location_description ILIKE '%RESTAURANT%' OR location_description ILIKE '%BUSINESS%'
            THEN 'Commercial'
            WHEN location_description ILIKE '%SCHOOL%' OR location_description ILIKE '%COLLEGE%'
            THEN 'Educational'
            WHEN location_description ILIKE '%PARK%' OR location_description ILIKE '%BEACH%'
            THEN 'Recreational'
            ELSE 'Other'
        END                                         AS location_category,
        
        -- Geographic coordinates
        CASE 
            WHEN latitude != 0 AND longitude != 0 THEN latitude 
            ELSE NULL 
        END                                         AS latitude,
        
        CASE 
            WHEN latitude != 0 AND longitude != 0 THEN longitude 
            ELSE NULL 
        END                                         AS longitude,
        
        CASE 
            WHEN x_coordinate != 0 THEN x_coordinate 
            ELSE NULL 
        END                                         AS x_coordinate,
        
        CASE 
            WHEN y_coordinate != 0 THEN y_coordinate 
            ELSE NULL 
        END                                         AS y_coordinate,
        
        -- Geographic hierarchy labels
        'Beat ' || beat                             AS beat_name,
        'District ' || district                     AS district_name,
        'Ward ' || ward                             AS ward_name,
        
        -- Data quality indicators
        CASE 
            WHEN latitude IS NOT NULL AND longitude IS NOT NULL 
            THEN TRUE 
            ELSE FALSE 
        END                                         AS has_coordinates,
        
        CURRENT_TIMESTAMP                           AS created_at

    FROM locations
)

SELECT * FROM location_dimension
ORDER BY district, beat, location_description