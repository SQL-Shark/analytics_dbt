{{
  config(
    materialized='table',
    indexes=[
      {'columns': ['date_key'], 'unique': True},
      {'columns': ['calendar_date']},
      {'columns': ['year_number', 'month_number']}
    ]
  )
}}

WITH date_spine AS (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2010-01-01' as date)",
        end_date="cast('2030-12-31' as date)"
    )}}
),

date_dimension AS (
    SELECT
        -- Surrogate key (YYYYMMDD format)
        TO_CHAR(date_day, 'YYYYMMDD')::INTEGER      AS date_key,
        
        -- Natural key
        date_day                                    AS calendar_date,
        
        -- Year attributes
        EXTRACT(YEAR FROM date_day)::INTEGER        AS year_number,
        'Y' || EXTRACT(YEAR FROM date_day)          AS year_name,
        
        -- Quarter attributes
        EXTRACT(QUARTER FROM date_day)::INTEGER     AS quarter_number,
        'Q' || EXTRACT(QUARTER FROM date_day) || 
        ' ' || EXTRACT(YEAR FROM date_day)          AS quarter_name,
        
        -- Month attributes
        EXTRACT(MONTH FROM date_day)::INTEGER       AS month_number,
        TO_CHAR(date_day, 'Month')                  AS month_name,
        TO_CHAR(date_day, 'Mon')                    AS month_short_name,
        'M' || LPAD(EXTRACT(MONTH FROM date_day)::TEXT, 2, '0') || 
        ' ' || EXTRACT(YEAR FROM date_day)          AS month_year_name,
        
        -- Week attributes
        EXTRACT(WEEK FROM date_day)::INTEGER        AS week_of_year,
        EXTRACT(DOW FROM date_day)::INTEGER         AS day_of_week_number,
        TO_CHAR(date_day, 'Day')                    AS day_of_week_name,
        TO_CHAR(date_day, 'Dy')                     AS day_of_week_short_name,
        
        -- Day attributes
        EXTRACT(DAY FROM date_day)::INTEGER         AS day_of_month,
        EXTRACT(DOY FROM date_day)::INTEGER         AS day_of_year,
        
        -- Business logic attributes
        CASE 
            WHEN EXTRACT(DOW FROM date_day) IN (0, 6) THEN FALSE 
            ELSE TRUE 
        END                                         AS is_weekday,
        
        CASE 
            WHEN EXTRACT(DOW FROM date_day) IN (0, 6) THEN TRUE 
            ELSE FALSE 
        END                                         AS is_weekend,
        
        -- Relative date attributes
        CASE 
            WHEN date_day = CURRENT_DATE THEN TRUE 
            ELSE FALSE 
        END                                         AS is_current_day,
        
        CASE 
            WHEN EXTRACT(YEAR FROM date_day) = EXTRACT(YEAR FROM CURRENT_DATE) 
            THEN TRUE 
            ELSE FALSE 
        END                                         AS is_current_year

    FROM date_spine
)

SELECT * FROM date_dimension
ORDER BY calendar_date
