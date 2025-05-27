{{
  config(materialized='view',schema='staging')
}}

WITH raw_data AS (
    SELECT
        -- Primary identifiers
        rcc."ID"::INTEGER                           AS crime_id,
        rcc."Case_Number"                           AS case_number,

        -- Temporal fields
        rcc."Date"::TIMESTAMP                       AS incident_datetime,
        rcc."Year"::INTEGER                         AS incident_year,
        DATE(rcc."Date"::TIMESTAMP)                 AS incident_date,

        -- Crime classification
        rcc."IUCR"                                  AS iucr_code,
        rcc."Primary_Type"                          AS primary_crime_type,
        rcc."Description"                           AS crime_description,
        rcc."FBI_Code"                              AS fbi_code,

        -- Location information
        rcc."Block"                                 AS block_address,
        rcc."Location_Description"                  AS location_description,
        rcc."Beat"                                  AS beat,
        rcc."District"                              AS district,
        rcc."Ward"::INTEGER                         AS ward,
        rcc."Community_Area"                        AS community_area,

        -- Geographic coordinates
        rcc."X_Coordinate"::NUMERIC                  AS x_coordinate,
        rcc."Y_Coordinate"::NUMERIC                  AS y_coordinate,
        rcc."Latitude"::NUMERIC                      AS latitude,
        rcc."Longitude"::NUMERIC                     AS longitude,

        -- Flags and indicators
        -- Corrected logic: If rcc."Arrest" is already boolean,
        -- you can directly use it.
        rcc."Arrest"                                AS was_arrest_made,

        -- Corrected logic: If rcc."Domestic" is already boolean,
        -- you can directly use it.
        rcc."Domestic"                              AS is_domestic_violence,

        -- Metadata
        rcc."Updated_On"::TIMESTAMP                 AS last_updated_at,

        -- Data quality flags
        CASE
            WHEN rcc."Date" IS NULL THEN 'MISSING_DATE'
            WHEN rcc."Primary_Type" IS NULL THEN 'MISSING_CRIME_TYPE'
            WHEN rcc."Location_Description" IS NULL THEN 'MISSING_LOCATION'
            ELSE 'VALID'
        END                                         AS data_quality_flag

    FROM {{ source('raw', 'raw_chicago_crimes') }} AS rcc
    WHERE rcc."ID" IS NOT NULL  -- Ensure we have valid records
)

SELECT * FROM raw_data
WHERE incident_year >= 2015