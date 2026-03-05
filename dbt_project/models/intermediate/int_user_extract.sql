-- Intermediate Model: int_user_extract
-- Converted from Informatica: SDE_ORA_UserDimension.xml - Sq_Users_Extract Source Qualifier
-- This model joins FND_USER with PER_ALL_PEOPLE_F to extract user information
-- Implements the SQL Query from the Informatica Source Qualifier transformation

{{ config(
    materialized='ephemeral'
) }}

WITH person_max_dates AS (
    -- Get the maximum effective start date for each person
    SELECT
        person_id,
        MAX(effective_start_date) AS max_eff_start_date
    FROM {{ ref('stg_oracle_per_all_people_f') }}
    GROUP BY person_id
),

users_with_people AS (
    SELECT
        a.user_id,
        a.user_name,
        a.email_address,
        a.changed_on_dt,
        a.last_updated_by,
        a.creation_date,
        a.created_by,
        a.fax,
        a.start_date AS user_start_date,
        a.end_date AS user_end_date,
        b.first_name,
        b.middle_names,
        b.last_name,
        b.full_name,
        -- Employee flag transformation from Informatica
        CASE WHEN b.current_employee_flag = 'Y' THEN 'Y' ELSE 'N' END AS current_employee_flag,
        b.title AS name_prefix,
        b.suffix,
        b.effective_start_date,
        b.last_update_date,
        b.sex,
        b.date_of_birth,
        b.marital_status,
        b.business_group_id,
        -- Address fields
        b.address_line1,
        b.address_line2,
        b.town_or_city,
        b.state_province,
        b.county,
        b.country,
        b.postal_code,
        b.work_telephone,
        b.known_as AS x_display_name,
        '0' AS x_custom
    FROM {{ ref('stg_oracle_fnd_user') }} a
    LEFT JOIN person_max_dates c
        ON a.employee_id = c.person_id
    LEFT JOIN {{ ref('stg_oracle_per_all_people_f') }} b
        ON c.person_id = b.person_id
        AND c.max_eff_start_date = b.effective_start_date
    WHERE 
        -- Incremental filter based on LAST_EXTRACT_DATE parameter
        a.changed_on_dt > TO_TIMESTAMP('{{ var("last_extract_date") }}', 'YYYY-MM-DD HH24:MI:SS')
        OR b.last_update_date > TO_TIMESTAMP('{{ var("last_extract_date") }}', 'YYYY-MM-DD HH24:MI:SS')
)

SELECT
    u.user_id,
    u.user_name,
    u.email_address AS primary_email_addr,
    u.changed_on_dt,
    u.last_updated_by,
    u.creation_date AS created_on_dt,
    u.created_by,
    u.fax AS fax_num,
    u.user_start_date,
    u.user_end_date,
    u.first_name,
    u.middle_names AS mid_name,
    u.last_name,
    u.full_name,
    u.current_employee_flag AS emp_flg,
    u.name_prefix,
    u.suffix AS name_suffix,
    u.effective_start_date AS src_eff_from_dt,
    u.last_update_date,
    u.sex AS sex_mf_code,
    u.date_of_birth,
    u.marital_status,
    -- Address fields
    u.address_line1 AS st_address,
    u.address_line2 AS st_address2,
    u.town_or_city AS city,
    u.state_province AS state_code,
    u.county,
    u.country AS country_code,
    u.postal_code AS zipcode,
    u.work_telephone AS work_phone_num,
    u.x_custom,
    d.ledger_name AS x_ledger_name,
    d.currency_code AS x_currency_code,
    d.business_group_name AS x_bus_group_name,
    d.operating_unit_name AS x_operating_unit_name,
    u.x_display_name,
    -- Generate Integration ID as USER_ID
    CAST(u.user_id AS VARCHAR(80)) AS integration_id,
    {{ var('datasource_num_id') }} AS datasource_num_id
FROM users_with_people u
LEFT JOIN {{ ref('stg_oracle_org_definitions') }} d
    ON u.business_group_id = d.business_group_id
