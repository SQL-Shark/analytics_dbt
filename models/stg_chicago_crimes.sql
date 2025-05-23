-- models/staging/stg_chicago_crimes.sql
{{ config(materialized='view') }}

with raw as (
  select
    case_number  as case_number,    -- lower-case alias
    date,
    primary_type,
    description,
    location_description,
    arrest,
    domestic
  from "{{ target.schema }}"."raw_chicago_crimes"
)

select
  Case_Number::varchar   as case_id,
  "Date"              as event_datetime,
  date("Date")        as crime_date,
  primary_type                as crime_type,
  description,
  location_description        as location,
  (arrest = 'true')           as is_arrest,
  (domestic = 'true')         as is_domestic
from raw