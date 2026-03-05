{{
    config(
        materialized='incremental',
        schema='DATA_WAREHOUSE',
        alias='W_USER_D_SCD_AUDIT',
        unique_key='OLD_ROW_WID',
        tags=['SIL', 'UserDimension', 'SCD_Update'],
        post_hook=[
            """
            UPDATE {{ source('warehouse', 'W_USER_D') }} tgt
            SET 
                CURRENT_FLG = 'N',
                EFFECTIVE_TO_DT = src.NEW_EFFECTIVE_TO_DT,
                W_UPDATE_DT = CURRENT_TIMESTAMP
            FROM {{ this }} src
            WHERE tgt.ROW_WID = src.OLD_ROW_WID
            AND tgt.CURRENT_FLG = 'Y'
            """
        ]
    )
}}

{#
    =====================================================================
    INFORMATICA MAPPING: m_SIL_UserDimension_Update (SCD Type 2)
    =====================================================================
    Purpose: SCD Type 2 - Close previous records when changes detected
    
    This mapping runs AFTER m_SIL_UserDimension to:
    1. Identify records that have changed (new version inserted)
    2. Update EFFECTIVE_TO_DT on old records to (new_effective_from - 1 day)
    3. Set CURRENT_FLG = 'N' on old records
    
    Source Table:
        - W_USER_D (newly inserted records from current run)
    
    Target Table:
        - W_USER_D (update existing records)
    
    Informatica Components:
        - SQ_NEW_RECORDS: Source Qualifier for new records
        - LKP_OLD_RECORD: Lookup to find existing current record
        - FIL_CHANGED: Filter for records that need closing
        - EXP_UPDATE_COLS: Expression to set update values
        - UPD_CLOSE_RECORD: Update Strategy (DD_UPDATE)
    =====================================================================
#}

WITH 
-- =====================================================================
-- SQ_NEW_RECORDS: Get newly inserted records from current run
-- Records inserted today with CURRENT_FLG = 'Y'
-- =====================================================================
SQ_NEW_RECORDS AS (
    SELECT 
        INTEGRATION_ID,
        ROW_WID,
        EFFECTIVE_FROM_DT,
        W_INSERT_DT
    FROM {{ ref('m_SIL_UserDimension') }}
    WHERE CAST(W_INSERT_DT AS DATE) = CURRENT_DATE
      AND CURRENT_FLG = 'Y'
),

-- =====================================================================
-- LKP_OLD_RECORD: Find previous current record for same INTEGRATION_ID
-- Equivalent to Informatica Lookup Transformation
-- =====================================================================
LKP_OLD_RECORD AS (
    SELECT
        new_rec.INTEGRATION_ID,
        new_rec.ROW_WID AS NEW_ROW_WID,
        new_rec.EFFECTIVE_FROM_DT AS NEW_EFFECTIVE_FROM_DT,
        old_rec.ROW_WID AS OLD_ROW_WID,
        old_rec.EFFECTIVE_FROM_DT AS OLD_EFFECTIVE_FROM_DT,
        old_rec.EFFECTIVE_TO_DT AS OLD_EFFECTIVE_TO_DT,
        old_rec.CURRENT_FLG AS OLD_CURRENT_FLG
    FROM SQ_NEW_RECORDS new_rec
    INNER JOIN {{ ref('m_SIL_UserDimension') }} old_rec
        ON new_rec.INTEGRATION_ID = old_rec.INTEGRATION_ID
        AND old_rec.CURRENT_FLG = 'Y'
        AND old_rec.ROW_WID != new_rec.ROW_WID
),

-- =====================================================================
-- FIL_NEEDS_UPDATE: Filter records that need to be closed
-- Equivalent to Informatica Filter Transformation
-- =====================================================================
FIL_NEEDS_UPDATE AS (
    SELECT *
    FROM LKP_OLD_RECORD
    WHERE OLD_CURRENT_FLG = 'Y'
),

-- =====================================================================
-- EXP_UPDATE_COLS: Prepare update values
-- Equivalent to Informatica Expression Transformation
-- Sets EFFECTIVE_TO_DT = NEW_EFFECTIVE_FROM_DT - 1 day
-- =====================================================================
EXP_UPDATE_COLS AS (
    SELECT
        INTEGRATION_ID,
        NEW_ROW_WID,
        OLD_ROW_WID,
        OLD_EFFECTIVE_FROM_DT,
        NEW_EFFECTIVE_FROM_DT,
        -- Close old record one day before new record starts
        DATEADD(DAY, -1, NEW_EFFECTIVE_FROM_DT) AS NEW_EFFECTIVE_TO_DT,
        'N' AS NEW_CURRENT_FLG,
        CURRENT_TIMESTAMP AS UPDATE_TIMESTAMP,
        'CLOSE_OLD_RECORD' AS UPDATE_ACTION
    FROM FIL_NEEDS_UPDATE
)

-- =====================================================================
-- Final SELECT - Audit/tracking table for SCD updates
-- The actual UPDATE is performed via post_hook
-- =====================================================================
SELECT
    OLD_ROW_WID,
    NEW_ROW_WID,
    INTEGRATION_ID,
    OLD_EFFECTIVE_FROM_DT,
    NEW_EFFECTIVE_FROM_DT,
    NEW_EFFECTIVE_TO_DT,
    NEW_CURRENT_FLG,
    UPDATE_TIMESTAMP,
    UPDATE_ACTION,
    'WF_SIL_UserDimension_Update' AS ETL_PROC_WID

FROM EXP_UPDATE_COLS
