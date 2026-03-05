-- Intermediate Model: int_user_with_lookups
-- Converted from Informatica: SIL_UserDimension.xml - Code Lookups (Gender, State, Country)
-- This model performs code lookups similar to LKP_CODES_GENDER, LKP_CODES_STATE, LKP_CODES_COUNTRY

{{ config(
    materialized='ephemeral'
) }}

WITH source_data AS (
    SELECT * FROM {{ ref('int_user_staging') }}
),

-- Gender code lookup (LKP_CODES_GENDER)
gender_codes AS (
    SELECT
        source_code,
        datasource_num_id,
        master_code,
        master_value
    FROM {{ source('warehouse', 'w_code_d') }}
    WHERE category = 'GENDER'
        AND language_code = '{{ var("language_code") }}'
),

-- State code lookup (LKP_CODES_STATE)
state_codes AS (
    SELECT
        source_code,
        datasource_num_id,
        master_code,
        master_value
    FROM {{ source('warehouse', 'w_code_d') }}
    WHERE category = 'STATE'
        AND language_code = '{{ var("language_code") }}'
),

-- Country code lookup (LKP_CODES_COUNTRY)
country_codes AS (
    SELECT
        source_code,
        datasource_num_id,
        master_code,
        master_value
    FROM {{ source('warehouse', 'w_code_d') }}
    WHERE category = 'COUNTRY'
        AND language_code = '{{ var("language_code") }}'
),

-- Marital Status code lookup (LKP_CODES_MARITAL_STATUS)
marital_status_codes AS (
    SELECT
        source_code,
        datasource_num_id,
        master_code,
        master_value
    FROM {{ source('warehouse', 'w_code_d') }}
    WHERE category = 'MARITAL_STATUS'
        AND language_code = '{{ var("language_code") }}'
),

-- Existing dimension lookup for SCD Type 2 processing
existing_dimension AS (
    SELECT
        row_wid,
        integration_id,
        datasource_num_id,
        effective_from_dt,
        effective_to_dt,
        delete_flg,
        w_insert_dt,
        current_flg
    FROM {{ source('warehouse', 'w_user_d') }}
    WHERE current_flg = 'Y'
)

SELECT
    sd.first_name,
    sd.mid_name,
    sd.last_name,
    sd.full_name,
    sd.name_prefix,
    sd.name_suffix,
    sd.name_eff_date,
    
    -- Sex/Gender code transformation (Exp_W_USER_D_Transform logic)
    CASE
        WHEN gc.master_code IS NOT NULL THEN gc.master_code
        WHEN sd.sex_mf_code IS NULL THEN '{{ var("source_code_not_supplied") }}'
        ELSE sd.sex_mf_code
    END AS sex_mf_code,
    CASE
        WHEN gc.master_value IS NOT NULL THEN gc.master_value
        WHEN gc.master_code IS NULL AND sd.sex_mf_code IS NOT NULL THEN '{{ var("master_code_not_found") }}'
        WHEN sd.sex_mf_name IS NOT NULL THEN sd.sex_mf_name
        ELSE '{{ var("source_code_not_supplied") }}'
    END AS sex_mf_name,
    
    -- Marital Status code transformation
    sd.date_of_birth,
    CASE
        WHEN ms.master_code IS NOT NULL THEN ms.master_code
        WHEN sd.marital_status IS NULL THEN '{{ var("source_code_not_supplied") }}'
        ELSE sd.marital_status
    END AS marital_status_code,
    CASE
        WHEN ms.master_value IS NOT NULL THEN ms.master_value
        WHEN ms.master_code IS NULL AND sd.marital_status IS NOT NULL THEN '{{ var("master_code_not_found") }}'
        ELSE '{{ var("source_code_not_supplied") }}'
    END AS marital_status_name,
    
    sd.st_address,
    sd.st_address2,
    sd.city,
    sd.county,
    
    -- State code transformation
    CASE
        WHEN sc.master_code IS NOT NULL THEN sc.master_code
        WHEN sd.state_code IS NULL THEN '{{ var("source_code_not_supplied") }}'
        ELSE sd.state_code
    END AS state_code,
    CASE
        WHEN sc.master_value IS NOT NULL THEN sc.master_value
        WHEN sc.master_code IS NULL AND sd.state_code IS NOT NULL THEN '{{ var("master_code_not_found") }}'
        WHEN sd.state_name IS NOT NULL THEN sd.state_name
        ELSE '{{ var("source_code_not_supplied") }}'
    END AS state_name,
    sd.state_region,
    
    -- Country code transformation
    CASE
        WHEN cc.master_code IS NOT NULL THEN cc.master_code
        WHEN sd.country_code IS NULL THEN '{{ var("source_code_not_supplied") }}'
        ELSE sd.country_code
    END AS country_code,
    CASE
        WHEN cc.master_value IS NOT NULL THEN cc.master_value
        WHEN cc.master_code IS NULL AND sd.country_code IS NOT NULL THEN '{{ var("master_code_not_found") }}'
        WHEN sd.country_name IS NOT NULL THEN sd.country_name
        ELSE '{{ var("source_code_not_supplied") }}'
    END AS country_name,
    sd.country_region,
    
    sd.zipcode,
    sd.post_office_box,
    sd.addr_eff_date,
    sd.work_phone_num,
    sd.mobile_phone_num,
    sd.pager_num,
    sd.fax_num,
    sd.primary_email_addr,
    sd.alternate_email_addr,
    sd.web_address,
    sd.supervisor_name,
    sd.department_name,
    sd.login,
    sd.user_formed_dt,
    sd.hire_dt,
    sd.term_dt,
    sd.contractor_flg,
    sd.agent_flg,
    sd.emp_flg,
    sd.active_flg,
    sd.created_by_id,
    sd.changed_by_id,
    sd.created_on_dt,
    sd.changed_on_dt,
    sd.aux1_changed_on_dt,
    sd.aux2_changed_on_dt,
    sd.aux3_changed_on_dt,
    sd.aux4_changed_on_dt,
    sd.src_eff_from_dt,
    sd.src_eff_to_dt,
    sd.delete_flg,
    sd.datasource_num_id,
    sd.integration_id,
    sd.tenant_id,
    sd.x_custom,
    sd.x_ledger_name,
    sd.x_currency_code,
    sd.x_bus_group_name,
    sd.x_operating_unit_name,
    sd.x_display_name,
    
    -- Existing dimension data for SCD processing
    ed.row_wid AS lkp_row_wid,
    ed.w_insert_dt AS lkp_w_insert_dt,
    ed.effective_from_dt AS lkp_effective_from_dt,
    ed.effective_to_dt AS lkp_effective_to_dt,
    ed.delete_flg AS lkp_delete_flg,
    
    -- Determine update flag (I=Insert, U=Update, S=SCD Type 2)
    CASE
        WHEN ed.row_wid IS NULL THEN 'I'  -- New record, insert
        WHEN sd.delete_flg = 'Y' AND COALESCE(ed.delete_flg, 'N') = 'N' THEN 'D'  -- Delete
        WHEN sd.delete_flg = 'Y' AND ed.delete_flg = 'Y' THEN 'B'  -- Already deleted
        ELSE 'U'  -- Update existing record
    END AS update_flg

FROM source_data sd
LEFT JOIN gender_codes gc
    ON sd.sex_mf_code = gc.source_code
    AND sd.datasource_num_id = gc.datasource_num_id
LEFT JOIN state_codes sc
    ON sd.state_code = sc.source_code
    AND sd.datasource_num_id = sc.datasource_num_id
LEFT JOIN country_codes cc
    ON sd.country_code = cc.source_code
    AND sd.datasource_num_id = cc.datasource_num_id
LEFT JOIN marital_status_codes ms
    ON sd.marital_status = ms.source_code
    AND sd.datasource_num_id = ms.datasource_num_id
LEFT JOIN existing_dimension ed
    ON sd.integration_id = ed.integration_id
    AND sd.datasource_num_id = ed.datasource_num_id
