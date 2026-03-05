-- Staging Model: stg_oracle_fnd_user
-- Converted from Informatica: SDE_ORA_UserDimension.xml - Source FND_USER
-- This is the source staging model that extracts data from FND_USER table

{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    user_id,
    user_name,
    email_address,
    last_update_date AS changed_on_dt,
    last_updated_by,
    creation_date,
    created_by,
    fax,
    start_date,
    end_date,
    description,
    last_logon_date,
    password_date,
    employee_id,
    person_party_id,
    customer_id,
    supplier_id
FROM {{ source('oracle_apps', 'fnd_user') }}
