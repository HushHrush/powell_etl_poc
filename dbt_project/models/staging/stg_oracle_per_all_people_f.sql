-- Staging Model: stg_oracle_per_all_people_f
-- Converted from Informatica: SDE_ORA_UserDimension.xml - Source PER_ALL_PEOPLE_F
-- This is the source staging model that extracts data from PER_ALL_PEOPLE_F table

{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    person_id,
    effective_start_date,
    effective_end_date,
    business_group_id,
    person_type_id,
    last_name,
    first_name,
    middle_names,
    full_name,
    title,
    pre_name_adjunct,
    suffix,
    known_as,
    sex,
    date_of_birth,
    marital_status,
    nationality,
    national_identifier,
    email_address,
    employee_number,
    applicant_number,
    current_employee_flag,
    current_emp_or_apl_flag,
    current_applicant_flag,
    address_line1,
    address_line2,
    address_line3,
    town_or_city,
    region_1 AS state_province,
    region_2 AS county,
    country,
    postal_code,
    work_telephone,
    attribute1,
    attribute2,
    last_update_date,
    last_updated_by,
    creation_date,
    created_by
FROM {{ source('oracle_apps', 'per_all_people_f') }}
