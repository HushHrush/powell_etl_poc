{{
    config(
        materialized='table',
        schema='DATA_WAREHOUSE',
        alias='W_USER_DS',
        tags=['SDE', 'UserDimension', 'Extract'],
        pre_hook="TRUNCATE TABLE IF EXISTS {{ this }}"
    )
}}

{#
    =====================================================================
    INFORMATICA MAPPING: m_SDE_ORA_UserDimension
    =====================================================================
    Purpose: Extract user data from Oracle EBS source tables
    
    Source Tables:
        - FND_USER (User accounts)
        - PER_ALL_PEOPLE_F (Person details - effective dated)
    
    Target Table:
        - W_USER_DS (User Dimension Staging)
    
    Transformations:
        - SQ_FND_USER: Source Qualifier reading FND_USER
        - SQ_PER_ALL_PEOPLE_F: Source Qualifier reading PER_ALL_PEOPLE_F
        - JNR_USER_PERSON: Joiner on EMPLOYEE_ID = PERSON_ID
        - FIL_ACTIVE_RECORDS: Filter for current effective dated records
        - EXP_TRANSFORM: Expression for derived columns
    =====================================================================
#}

WITH 
-- =====================================================================
-- SQ_FND_USER: Source Qualifier for FND_USER table
-- =====================================================================
SQ_FND_USER AS (
    SELECT
        USER_ID,
        USER_NAME,
        PERSON_PARTY_ID,
        EMAIL_ADDRESS,
        START_DATE AS USER_START_DATE,
        END_DATE AS USER_END_DATE,
        EMPLOYEE_ID,
        CREATED_BY,
        CREATION_DATE,
        LAST_UPDATED_BY,
        LAST_UPDATE_DATE
    FROM {{ source('oracle_apps', 'FND_USER') }}
),

-- =====================================================================
-- SQ_PER_ALL_PEOPLE_F: Source Qualifier for PER_ALL_PEOPLE_F table
-- =====================================================================
SQ_PER_ALL_PEOPLE_F AS (
    SELECT
        PERSON_ID,
        EFFECTIVE_START_DATE,
        EFFECTIVE_END_DATE,
        EMPLOYEE_NUMBER,
        TITLE,
        FIRST_NAME,
        MIDDLE_NAMES,
        LAST_NAME,
        FULL_NAME,
        KNOWN_AS,
        PRE_NAME_ADJUNCT,
        SUFFIX,
        SEX,
        DATE_OF_BIRTH,
        MARITAL_STATUS,
        NATIONALITY,
        NATIONAL_IDENTIFIER,
        ADDRESS_LINE1,
        ADDRESS_LINE2,
        ADDRESS_LINE3,
        TOWN_OR_CITY,
        REGION_1,
        REGION_2,
        COUNTRY,
        POSTAL_CODE,
        WORK_TELEPHONE,
        BUSINESS_GROUP_ID,
        CURRENT_EMPLOYEE_FLAG
    FROM {{ source('oracle_apps', 'PER_ALL_PEOPLE_F') }}
),

-- =====================================================================
-- FIL_CURRENT_PERSON: Filter for current effective dated records
-- Informatica Filter Transformation equivalent
-- =====================================================================
FIL_CURRENT_PERSON AS (
    SELECT *
    FROM SQ_PER_ALL_PEOPLE_F
    WHERE CURRENT_DATE BETWEEN EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE
),

-- =====================================================================
-- JNR_USER_PERSON: Joiner Transformation
-- Join Type: LEFT OUTER (Master: FND_USER, Detail: PER_ALL_PEOPLE_F)
-- Condition: FND_USER.EMPLOYEE_ID = PER_ALL_PEOPLE_F.PERSON_ID
-- =====================================================================
JNR_USER_PERSON AS (
    SELECT
        u.USER_ID,
        u.USER_NAME,
        u.EMAIL_ADDRESS,
        u.USER_START_DATE,
        u.USER_END_DATE,
        u.EMPLOYEE_ID,
        u.CREATED_BY,
        u.CREATION_DATE,
        u.LAST_UPDATED_BY,
        u.LAST_UPDATE_DATE,
        p.PERSON_ID,
        p.EMPLOYEE_NUMBER,
        p.TITLE,
        p.FIRST_NAME,
        p.MIDDLE_NAMES,
        p.LAST_NAME,
        p.FULL_NAME,
        p.KNOWN_AS,
        p.PRE_NAME_ADJUNCT,
        p.SUFFIX,
        p.SEX,
        p.DATE_OF_BIRTH,
        p.MARITAL_STATUS,
        p.NATIONALITY,
        p.NATIONAL_IDENTIFIER,
        p.ADDRESS_LINE1,
        p.ADDRESS_LINE2,
        p.ADDRESS_LINE3,
        p.TOWN_OR_CITY,
        p.REGION_1,
        p.REGION_2,
        p.COUNTRY,
        p.POSTAL_CODE,
        p.WORK_TELEPHONE,
        p.BUSINESS_GROUP_ID,
        p.CURRENT_EMPLOYEE_FLAG,
        p.EFFECTIVE_START_DATE,
        p.EFFECTIVE_END_DATE
    FROM SQ_FND_USER u
    LEFT OUTER JOIN FIL_CURRENT_PERSON p
        ON u.EMPLOYEE_ID = p.PERSON_ID
),

-- =====================================================================
-- LKP_ORG_DEFINITIONS: Lookup for Organization/Business Group Info
-- =====================================================================
LKP_ORG_DEFINITIONS AS (
    SELECT
        j.*,
        org.ORGANIZATION_NAME AS BUS_GRP_NAME,
        gsob.NAME AS LEDGER_NAME,
        gsob.CURRENCY_CODE
    FROM JNR_USER_PERSON j
    LEFT JOIN {{ source('oracle_apps', 'ORG_ORGANIZATION_DEFINITIONS') }} org
        ON j.BUSINESS_GROUP_ID = org.ORGANIZATION_ID
    LEFT JOIN {{ source('oracle_apps', 'GL_SETS_OF_BOOKS') }} gsob
        ON org.SET_OF_BOOKS_ID = gsob.SET_OF_BOOKS_ID
),

-- =====================================================================
-- EXP_TRANSFORM: Expression Transformation
-- Calculate derived columns and apply business logic
-- =====================================================================
EXP_TRANSFORM AS (
    SELECT
        -- Primary Keys
        USER_ID,
        PERSON_ID,
        
        -- Integration ID (Natural Key)
        CAST(USER_ID AS VARCHAR(80)) AS INTEGRATION_ID,
        
        -- User Information
        USER_NAME,
        EMAIL_ADDRESS,
        USER_START_DATE,
        USER_END_DATE,
        
        -- Person Name Fields
        COALESCE(TITLE, PRE_NAME_ADJUNCT) AS NAME_PREFIX,
        FIRST_NAME,
        MIDDLE_NAMES AS MID_NAME,
        LAST_NAME,
        FULL_NAME,
        COALESCE(KNOWN_AS, FIRST_NAME) AS DISPLAY_NAME,
        SUFFIX AS NAME_SUFFIX,
        
        -- Demographics
        SEX AS SEX_MF_CODE,
        DATE_OF_BIRTH,
        MARITAL_STATUS AS MARITAL_STATUS_CODE,
        NATIONALITY,
        NATIONAL_IDENTIFIER AS SSN,
        
        -- Address Fields
        ADDRESS_LINE1 AS ST_ADDRESS1,
        ADDRESS_LINE2 AS ST_ADDRESS2,
        ADDRESS_LINE3 AS ST_ADDRESS3,
        TOWN_OR_CITY AS CITY,
        REGION_1 AS STATE_CODE,
        REGION_2 AS COUNTY,
        COUNTRY AS COUNTRY_CODE,
        POSTAL_CODE AS ZIPCODE,
        
        -- Contact Information
        WORK_TELEPHONE AS WORK_PHONE_NUM,
        
        -- Employee Information
        EMPLOYEE_ID,
        EMPLOYEE_NUMBER AS EMP_NUM,
        
        -- Organization Info
        BUS_GRP_NAME,
        LEDGER_NAME,
        CURRENCY_CODE,
        
        -- Flags (Informatica IIF equivalent)
        CASE 
            WHEN CURRENT_EMPLOYEE_FLAG = 'Y' THEN 'Y'
            WHEN EMPLOYEE_ID IS NOT NULL THEN 'Y' 
            ELSE 'N' 
        END AS EMP_FLG,
        
        CASE 
            WHEN USER_END_DATE IS NULL OR USER_END_DATE > CURRENT_DATE THEN 'Y'
            ELSE 'N'
        END AS ACTIVE_FLG,
        
        -- Dates
        USER_START_DATE AS HIRE_DT,
        USER_END_DATE AS TERM_DT,
        EFFECTIVE_START_DATE AS SRC_EFF_FROM_DT,
        EFFECTIVE_END_DATE AS SRC_EFF_TO_DT,
        
        -- Audit Columns
        CREATED_BY,
        CREATION_DATE AS CREATED_ON_DT,
        LAST_UPDATED_BY,
        LAST_UPDATE_DATE AS CHANGED_ON_DT,
        
        -- ETL Metadata
        {{ var('datasource_num_id', 1) }} AS DATASOURCE_NUM_ID,
        'WF_SDE_ORA_UserDimension' AS ETL_PROC_WID,
        CURRENT_TIMESTAMP AS W_INSERT_DT,
        CURRENT_TIMESTAMP AS W_UPDATE_DT
        
    FROM LKP_ORG_DEFINITIONS
)

-- =====================================================================
-- Final SELECT - Target: W_USER_DS
-- =====================================================================
SELECT * FROM EXP_TRANSFORM
