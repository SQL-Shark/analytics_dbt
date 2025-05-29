{{
  config(
    materialized='table'
  )
}}

WITH locations AS (
  SELECT DISTINCT
    COALESCE(beat::text, '-1') as beat,  -- Convert to text, use -1 for unknown
    COALESCE(district::text, '-1') as district,  -- Convert to text, use -1 for unknown
    COALESCE(ward::text, '-1') as ward,  -- Use -1 for unknown ward
    COALESCE(community_area::text, '-1') as community_area,  -- Convert to text, use -1 for unknown
    COALESCE(location_description, 'Unknown') as location_description,
    -- Handle nulls in geographic coordinates
    COALESCE(latitude, 0) AS latitude,
    COALESCE(longitude, 0) AS longitude,
    COALESCE(x_coordinate, 0) AS x_coordinate,
    COALESCE(y_coordinate, 0) AS y_coordinate
  FROM {{ ref('stg_chicago_crimes') }}
),

location_dimension AS (
  SELECT
    -- Use ROW_NUMBER to ensure unique keys
    ROW_NUMBER() OVER (ORDER BY beat, district, ward, community_area, location_description) AS location_key,
    
    -- Administrative geography
    beat,
    district,
    ward,
    community_area,
    
    -- Location description
    location_description,
    
    -- Location categories
    CASE 
      WHEN location_description ILIKE '%STREET%' OR location_description ILIKE '%SIDEWALK%'
      THEN 'Street/Public Area'
      WHEN location_description ILIKE '%RESIDENCE%' OR location_description ILIKE '%APARTMENT%'
      THEN 'Residential'
      WHEN location_description ILIKE '%STORE%' OR location_description ILIKE '%RESTAURANT%'
      THEN 'Commercial'
      WHEN location_description ILIKE '%SCHOOL%' OR location_description ILIKE '%COLLEGE%'
      THEN 'Educational'
      WHEN location_description ILIKE '%PARK%' OR location_description ILIKE '%BEACH%'
      THEN 'Recreational'
      ELSE 'Other'
    END AS location_category,
    
    -- Geographic coordinates
    CASE WHEN latitude != 0 AND longitude != 0 THEN latitude ELSE NULL END AS latitude,
    CASE WHEN latitude != 0 AND longitude != 0 THEN longitude ELSE NULL END AS longitude,
    CASE WHEN x_coordinate != 0 THEN x_coordinate ELSE NULL END AS x_coordinate,
    CASE WHEN y_coordinate != 0 THEN y_coordinate ELSE NULL END AS y_coordinate,
    
    -- Geographic hierarchy labels
    CASE 
      WHEN beat = '-1' THEN 'Unknown Beat'
      ELSE 'Beat ' || beat 
    END AS beat_name,
    CASE 
      WHEN district = '-1' THEN 'Unknown District'
      ELSE 'District ' || district 
    END AS district_name,
    CASE 
      WHEN ward = '-1' THEN 'Unknown Ward'
      ELSE 'Ward ' || ward 
    END AS ward_name,
    
    -- Data quality indicators
    CASE 
      WHEN latitude IS NOT NULL AND longitude IS NOT NULL
      THEN TRUE
      ELSE FALSE
    END AS has_coordinates,
    
    CURRENT_TIMESTAMP AS created_at
  FROM locations
)

SELECT * 
FROM location_dimension
ORDER BY district, beat, location_description