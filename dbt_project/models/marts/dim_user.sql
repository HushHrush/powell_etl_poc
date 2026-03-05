-- Mart Model: dim_user (W_USER_D)
-- Converted from Informatica: SIL_UserDimension.xml
-- This is the final User Dimension table with SCD Type 2 support
-- Target table: W_USER_D

{{ config(
    materialized='incremental',
    unique_key=['integration_id', 'datasource_num_id', 'effective_from_dt'],
    schema='marts',
    on_schema_change='sync_all_columns'
) }}

WITH source_data AS (
    SELECT * FROM {{ ref('int_user_with_lookups') }}
),

-- Generate surrogate keys using row_number (equivalent to Seq_W_USER_D_Wid)
with_surrogate_keys AS (
    SELECT
        sd.*,
        
        -- EXP_SCD2_DATES logic - Calculate effective dates
        CASE
            WHEN sd.src_eff_from_dt IS NULL THEN TO_DATE('{{ var("default_eff_from_date") }}', 'YYYY-MM-DD')
            ELSE sd.src_eff_from_dt
        END AS calc_effective_from_dt,
        
        CASE
            WHEN sd.src_eff_to_dt IS NULL THEN TO_DATE('{{ var("default_eff_to_date") }}', 'YYYY-MM-DD')
            WHEN sd.src_eff_from_dt > sd.src_eff_to_dt THEN TO_DATE('{{ var("default_eff_to_date") }}', 'YYYY-MM-DD')
            ELSE sd.src_eff_to_dt
        END AS calc_effective_to_dt,
        
        -- Determine final update flag based on SCD logic
        CASE
            WHEN sd.update_flg = 'S' AND sd.lkp_effective_from_dt < sd.changed_on_dt THEN
                CASE WHEN sd.changed_on_dt < COALESCE(sd.src_eff_to_dt, TO_DATE('{{ var("default_eff_to_date") }}', 'YYYY-MM-DD')) 
                     THEN 'S' 
                     ELSE 'U' 
                END
            ELSE sd.update_flg
        END AS final_update_flg

    FROM source_data sd
),

-- Apply SCD Type 2 logic based on update flag
final_records AS (
    SELECT
        -- ROW_WID: Use existing or generate new
        CASE
            WHEN final_update_flg IN ('I', 'B', 'S') THEN 
                {{ dbt_utils.generate_surrogate_key(['integration_id', 'datasource_num_id', 'CURRENT_TIMESTAMP']) }}
            ELSE CAST(lkp_row_wid AS VARCHAR)
        END AS row_wid_key,
        
        COALESCE(lkp_row_wid, ROW_NUMBER() OVER (ORDER BY integration_id) + 
            (SELECT COALESCE(MAX(row_wid), 0) FROM {{ source('warehouse', 'w_user_d') }})) AS row_wid,
        
        first_name,
        mid_name,
        last_name,
        full_name,
        name_prefix,
        name_suffix,
        name_eff_date,
        sex_mf_code,
        sex_mf_name,
        marital_status_code,
        marital_status_name,
        date_of_birth,
        st_address,
        st_address2,
        city,
        county,
        state_code,
        state_name,
        state_region,
        country_code,
        country_name,
        country_region,
        zipcode,
        post_office_box,
        addr_eff_date,
        work_phone_num,
        mobile_phone_num,
        pager_num,
        fax_num,
        primary_email_addr,
        alternate_email_addr,
        web_address,
        supervisor_name,
        department_name,
        login,
        user_formed_dt,
        hire_dt,
        term_dt,
        contractor_flg,
        agent_flg,
        emp_flg,
        active_flg,
        
        -- Created/Changed by WID lookups would need separate lookup
        NULL AS created_by_wid,
        NULL AS changed_by_wid,
        
        created_on_dt,
        changed_on_dt,
        aux1_changed_on_dt,
        aux2_changed_on_dt,
        aux3_changed_on_dt,
        aux4_changed_on_dt,
        src_eff_from_dt,
        src_eff_to_dt,
        
        -- EFFECTIVE_FROM_DT logic from EXP_SCD2_DATES
        CASE
            WHEN final_update_flg IN ('I', 'B') THEN calc_effective_from_dt
            WHEN final_update_flg = 'S' THEN COALESCE(changed_on_dt, CURRENT_TIMESTAMP)
            WHEN final_update_flg IN ('U', 'D') THEN lkp_effective_from_dt
            ELSE calc_effective_from_dt
        END AS effective_from_dt,
        
        -- EFFECTIVE_TO_DT logic from EXP_SCD2_DATES
        CASE
            WHEN final_update_flg IN ('I', 'S') THEN TO_DATE('{{ var("default_eff_to_date") }}', 'YYYY-MM-DD')
            WHEN final_update_flg = 'B' THEN COALESCE(calc_effective_to_dt, CURRENT_TIMESTAMP)
            WHEN final_update_flg IN ('U', 'D') THEN 
                CASE WHEN lkp_effective_from_dt < calc_effective_to_dt 
                     THEN calc_effective_to_dt 
                     ELSE lkp_effective_to_dt 
                END
            ELSE calc_effective_to_dt
        END AS effective_to_dt,
        
        -- DELETE_FLG logic
        CASE
            WHEN final_update_flg IN ('B', 'D') THEN 'Y'
            ELSE 'N'
        END AS delete_flg,
        
        -- CURRENT_FLG - Always 'Y' for new/updated current records
        'Y' AS current_flg,
        
        -- W_INSERT_DT
        CASE
            WHEN final_update_flg IN ('I', 'B', 'S') THEN CURRENT_TIMESTAMP
            ELSE lkp_w_insert_dt
        END AS w_insert_dt,
        
        -- W_UPDATE_DT - Always current timestamp
        CURRENT_TIMESTAMP AS w_update_dt,
        
        datasource_num_id,
        
        -- ETL_PROC_WID would come from W_PARAM_G lookup
        1 AS etl_proc_wid,
        
        integration_id,
        tenant_id,
        x_custom,
        x_ledger_name,
        x_currency_code,
        x_bus_group_name,
        x_operating_unit_name,
        x_display_name,
        
        final_update_flg

    FROM with_surrogate_keys
    WHERE final_update_flg IS NOT NULL
)

SELECT
    row_wid,
    first_name,
    mid_name,
    last_name,
    full_name,
    name_prefix,
    name_suffix,
    name_eff_date,
    sex_mf_code,
    sex_mf_name,
    marital_status_code,
    marital_status_name,
    date_of_birth AS birth_dt,
    st_address AS address1,
    st_address2 AS address2,
    city,
    county,
    state_code,
    state_name,
    state_region,
    country_code,
    country_name,
    country_region,
    zipcode,
    post_office_box,
    addr_eff_date,
    work_phone_num,
    mobile_phone_num,
    pager_num,
    fax_num,
    primary_email_addr,
    alternate_email_addr,
    web_address,
    supervisor_name,
    department_name,
    login,
    user_formed_dt,
    hire_dt,
    term_dt,
    contractor_flg,
    agent_flg,
    emp_flg,
    active_flg,
    created_by_wid,
    changed_by_wid,
    created_on_dt,
    changed_on_dt,
    aux1_changed_on_dt,
    aux2_changed_on_dt,
    aux3_changed_on_dt,
    aux4_changed_on_dt,
    src_eff_from_dt,
    src_eff_to_dt,
    effective_from_dt,
    effective_to_dt,
    delete_flg,
    current_flg,
    w_insert_dt,
    w_update_dt,
    datasource_num_id,
    etl_proc_wid,
    integration_id,
    tenant_id,
    x_custom,
    x_ledger_name,
    x_currency_code,
    x_bus_group_name,
    x_operating_unit_name,
    x_display_name
FROM final_records

{% if is_incremental() %}
WHERE final_update_flg IN ('I', 'U', 'S', 'D', 'B')
{% endif %}
