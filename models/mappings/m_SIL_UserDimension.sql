{{
    config(
        materialized='incremental',
        schema='DATA_WAREHOUSE',
        alias='W_USER_D',
        unique_key='INTEGRATION_ID',
        incremental_strategy='merge',
        tags=['SIL', 'UserDimension', 'Load'],
        merge_update_columns=['FIRST_NAME', 'MID_NAME', 'LAST_NAME', 'FULL_NAME', 
                              'SEX_MF_CODE', 'SEX_MF_NAME', 'MARITAL_STATUS_CODE',
                              'MARITAL_STATUS_NAME', 'ADDRESS1', 'ADDRESS2', 'CITY',
                              'STATE_CODE', 'STATE_NAME', 'COUNTRY_CODE', 'COUNTRY_NAME',
                              'ZIPCODE', 'WORK_PHONE', 'ACTIVE_FLG', 'TERM_DT',
                              'W_UPDATE_DT', 'CURRENT_FLG', 'DELETE_FLG']
    )
}}

{#
    =====================================================================
    INFORMATICA MAPPING: m_SIL_UserDimension
    =====================================================================
    Purpose: Load staging data into User Dimension with lookups and SCD Type 2
    
    Source Table:
        - W_USER_DS (User Dimension Staging - from m_SDE_ORA_UserDimension)
    
    Target Table:
        - W_USER_D (User Dimension)
    
    Transformations:
        - SQ_USER_STAGING: Source Qualifier for W_USER_DS
        - LKP_GENDER: Lookup for gender code description
        - LKP_COUNTRY: Lookup for country name
        - LKP_STATE: Lookup for state name
        - LKP_MARITAL_STATUS: Lookup for marital status description
        - LKP_EXISTING_RECORD: Lookup to check if record exists (for SCD)
        - EXP_SCD_LOGIC: Expression for SCD Type 2 logic
        - RTR_INSERT_UPDATE: Router for Insert vs Update
        - UPD_INSERT: Update Strategy for Inserts
    =====================================================================
#}

WITH 
-- =====================================================================
-- SQ_USER_STAGING: Source Qualifier for W_USER_DS
-- =====================================================================
SQ_USER_STAGING AS (
    SELECT *
    FROM {{ ref('m_SDE_ORA_UserDimension') }}
),

-- =====================================================================
-- LKP_GENDER: Lookup Transformation for Gender Code
-- Lookup Table: W_CODE_D
-- Lookup Condition: CATEGORY = 'GENDER' AND SOURCE_CODE = SEX_MF_CODE
-- =====================================================================
LKP_GENDER AS (
    SELECT
        stg.*,
        COALESCE(gender_lkp.MASTER_VALUE, 
            CASE stg.SEX_MF_CODE
                WHEN 'M' THEN 'Male'
                WHEN 'F' THEN 'Female'
                ELSE 'Unknown'
            END
        ) AS SEX_MF_NAME
    FROM SQ_USER_STAGING stg
    LEFT JOIN {{ source('warehouse', 'W_CODE_D') }} gender_lkp
        ON stg.SEX_MF_CODE = gender_lkp.SOURCE_CODE
        AND gender_lkp.CATEGORY = 'GENDER'
        AND gender_lkp.LANGUAGE_CODE = '{{ var("language_code", "E") }}'
),

-- =====================================================================
-- LKP_COUNTRY: Lookup Transformation for Country Name
-- Lookup Table: W_CODE_D
-- Lookup Condition: CATEGORY = 'COUNTRY' AND SOURCE_CODE = COUNTRY_CODE
-- =====================================================================
LKP_COUNTRY AS (
    SELECT
        stg.*,
        COALESCE(country_lkp.MASTER_VALUE, stg.COUNTRY_CODE) AS COUNTRY_NAME
    FROM LKP_GENDER stg
    LEFT JOIN {{ source('warehouse', 'W_CODE_D') }} country_lkp
        ON stg.COUNTRY_CODE = country_lkp.SOURCE_CODE
        AND country_lkp.CATEGORY = 'COUNTRY'
        AND country_lkp.LANGUAGE_CODE = '{{ var("language_code", "E") }}'
),

-- =====================================================================
-- LKP_STATE: Lookup Transformation for State Name
-- Lookup Table: W_CODE_D
-- Lookup Condition: CATEGORY = 'STATE' AND SOURCE_CODE = STATE_CODE
-- =====================================================================
LKP_STATE AS (
    SELECT
        stg.*,
        COALESCE(state_lkp.MASTER_VALUE, stg.STATE_CODE) AS STATE_NAME
    FROM LKP_COUNTRY stg
    LEFT JOIN {{ source('warehouse', 'W_CODE_D') }} state_lkp
        ON stg.STATE_CODE = state_lkp.SOURCE_CODE
        AND state_lkp.CATEGORY = 'STATE'
        AND state_lkp.LANGUAGE_CODE = '{{ var("language_code", "E") }}'
),

-- =====================================================================
-- LKP_MARITAL_STATUS: Lookup Transformation for Marital Status
-- Lookup Table: W_CODE_D
-- Lookup Condition: CATEGORY = 'MARITAL_STATUS' AND SOURCE_CODE = MARITAL_STATUS_CODE
-- =====================================================================
LKP_MARITAL_STATUS AS (
    SELECT
        stg.*,
        COALESCE(ms_lkp.MASTER_VALUE,
            CASE stg.MARITAL_STATUS_CODE
                WHEN 'S' THEN 'Single'
                WHEN 'M' THEN 'Married'
                WHEN 'D' THEN 'Divorced'
                WHEN 'W' THEN 'Widowed'
                ELSE 'Unknown'
            END
        ) AS MARITAL_STATUS_NAME
    FROM LKP_STATE stg
    LEFT JOIN {{ source('warehouse', 'W_CODE_D') }} ms_lkp
        ON stg.MARITAL_STATUS_CODE = ms_lkp.SOURCE_CODE
        AND ms_lkp.CATEGORY = 'MARITAL_STATUS'
        AND ms_lkp.LANGUAGE_CODE = '{{ var("language_code", "E") }}'
),

{% if is_incremental() %}
-- =====================================================================
-- LKP_EXISTING_RECORD: Lookup to check existing records for SCD Type 2
-- This is only used in incremental runs
-- =====================================================================
LKP_EXISTING_RECORD AS (
    SELECT
        src.*,
        tgt.ROW_WID AS EXISTING_ROW_WID,
        tgt.INTEGRATION_ID AS EXISTING_INTEGRATION_ID,
        tgt.W_INSERT_DT AS EXISTING_W_INSERT_DT,
        tgt.EFFECTIVE_FROM_DT AS EXISTING_EFFECTIVE_FROM_DT,
        -- Check if any SCD columns have changed
        CASE WHEN (
            COALESCE(src.FIRST_NAME, '') != COALESCE(tgt.FIRST_NAME, '') OR
            COALESCE(src.LAST_NAME, '') != COALESCE(tgt.LAST_NAME, '') OR
            COALESCE(src.FULL_NAME, '') != COALESCE(tgt.FULL_NAME, '') OR
            COALESCE(src.SEX_MF_CODE, '') != COALESCE(tgt.SEX_MF_CODE, '') OR
            COALESCE(src.ACTIVE_FLG, '') != COALESCE(tgt.ACTIVE_FLG, '') OR
            COALESCE(src.ST_ADDRESS1, '') != COALESCE(tgt.ADDRESS1, '') OR
            COALESCE(src.CITY, '') != COALESCE(tgt.CITY, '') OR
            COALESCE(src.STATE_CODE, '') != COALESCE(tgt.STATE_CODE, '') OR
            COALESCE(src.COUNTRY_CODE, '') != COALESCE(tgt.COUNTRY_CODE, '')
        ) THEN 'Y' ELSE 'N' END AS CHANGED_FLG
    FROM LKP_MARITAL_STATUS src
    LEFT JOIN {{ this }} tgt
        ON src.INTEGRATION_ID = tgt.INTEGRATION_ID
        AND tgt.CURRENT_FLG = 'Y'
),

-- =====================================================================
-- EXP_SCD_LOGIC: Expression for SCD Type 2 logic
-- Determines whether record is INSERT, UPDATE, or NOCHANGE
-- =====================================================================
EXP_SCD_LOGIC AS (
    SELECT
        *,
        CASE 
            WHEN EXISTING_ROW_WID IS NULL THEN 'INSERT'
            WHEN CHANGED_FLG = 'Y' THEN 'UPDATE'
            ELSE 'NOCHANGE'
        END AS SCD_ACTION
    FROM LKP_EXISTING_RECORD
),

-- =====================================================================
-- RTR_INSERT_UPDATE: Router - Only process INSERT and UPDATE records
-- Equivalent to Informatica Router Transformation
-- =====================================================================
RTR_INSERT AS (
    SELECT * FROM EXP_SCD_LOGIC
    WHERE SCD_ACTION IN ('INSERT', 'UPDATE')
)

{% else %}
-- Full refresh - all records are inserts
RTR_INSERT AS (
    SELECT 
        *,
        NULL AS EXISTING_ROW_WID,
        NULL AS EXISTING_INTEGRATION_ID,
        NULL AS EXISTING_W_INSERT_DT,
        NULL AS EXISTING_EFFECTIVE_FROM_DT,
        'N' AS CHANGED_FLG,
        'INSERT' AS SCD_ACTION
    FROM LKP_MARITAL_STATUS
)
{% endif %}

-- =====================================================================
-- Final SELECT - Target: W_USER_D (Insert new/changed records)
-- Equivalent to Informatica Target transformation
-- =====================================================================
SELECT
    -- Surrogate Key (SEQ_W_USER_D_WID equivalent)
    {{ dbt_utils.generate_surrogate_key(['INTEGRATION_ID', 'SCD_ACTION', 'CURRENT_TIMESTAMP()']) }} AS ROW_WID,
    
    -- Integration ID (Natural Key)
    INTEGRATION_ID,
    
    -- User/Login Information
    USER_ID,
    USER_NAME AS LOGIN,
    
    -- Name Fields
    NAME_PREFIX,
    FIRST_NAME,
    MID_NAME,
    LAST_NAME,
    FULL_NAME,
    NAME_SUFFIX,
    DISPLAY_NAME,
    
    -- Demographics with Lookups Applied
    SEX_MF_CODE,
    SEX_MF_NAME,
    MARITAL_STATUS_CODE,
    MARITAL_STATUS_NAME,
    DATE_OF_BIRTH AS BIRTH_DT,
    
    -- Address Fields
    ST_ADDRESS1 AS ADDRESS1,
    ST_ADDRESS2 AS ADDRESS2,
    CITY,
    STATE_CODE,
    STATE_NAME,
    COUNTRY_CODE,
    COUNTRY_NAME,
    ZIPCODE,
    
    -- Contact
    WORK_PHONE_NUM AS WORK_PHONE,
    EMAIL_ADDRESS AS PRIMARY_EMAIL_ADDR,
    
    -- Employment
    EMP_FLG,
    EMP_NUM,
    ACTIVE_FLG,
    HIRE_DT,
    TERM_DT,
    
    -- Organization
    BUS_GRP_NAME,
    LEDGER_NAME,
    CURRENCY_CODE,
    
    -- SCD Type 2 Columns
    CASE 
        WHEN SCD_ACTION = 'INSERT' THEN COALESCE(SRC_EFF_FROM_DT, CURRENT_DATE)
        WHEN SCD_ACTION = 'UPDATE' THEN CURRENT_DATE
        ELSE COALESCE(EXISTING_EFFECTIVE_FROM_DT, CURRENT_DATE)
    END AS EFFECTIVE_FROM_DT,
    
    TO_DATE('{{ var("default_eff_to_date", "4712-12-31") }}', 'YYYY-MM-DD') AS EFFECTIVE_TO_DT,
    
    'Y' AS CURRENT_FLG,
    'N' AS DELETE_FLG,
    
    -- ETL Metadata
    DATASOURCE_NUM_ID,
    'WF_SIL_UserDimension' AS ETL_PROC_WID,
    
    CASE 
        WHEN SCD_ACTION = 'INSERT' THEN CURRENT_TIMESTAMP
        ELSE COALESCE(EXISTING_W_INSERT_DT, CURRENT_TIMESTAMP)
    END AS W_INSERT_DT,
    
    CURRENT_TIMESTAMP AS W_UPDATE_DT

FROM RTR_INSERT
