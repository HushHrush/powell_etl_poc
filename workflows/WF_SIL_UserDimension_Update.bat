@echo off
REM =====================================================================
REM WORKFLOW: WF_SIL_UserDimension_Update
REM Description: SCD Type 2 - Close previous records
REM Equivalent to: Informatica Workflow WF_SIL_UserDimension_Update
REM 
REM Mapping(s) Called:
REM   - m_SIL_UserDimension_Update
REM
REM Purpose:
REM   This workflow runs AFTER WF_SIL_UserDimension to:
REM   1. Identify records that have new versions inserted
REM   2. Close old records by setting:
REM      - CURRENT_FLG = 'N'
REM      - EFFECTIVE_TO_DT = (new record's EFFECTIVE_FROM_DT - 1 day)
REM
REM Source Tables:
REM   - DATA_WAREHOUSE.W_USER_D (newly inserted records)
REM
REM Target Table:
REM   - DATA_WAREHOUSE.W_USER_D (update old records via post_hook)
REM   - DATA_WAREHOUSE.W_USER_D_SCD_AUDIT (audit trail)
REM =====================================================================

echo =====================================================================
echo Starting Workflow: WF_SIL_UserDimension_Update
echo Timestamp: %DATE% %TIME%
echo =====================================================================

REM Navigate to dbt project directory
cd /d "%~dp0.."

REM Set environment (can be overridden)
IF "%DBT_TARGET%"=="" SET DBT_TARGET=dev

echo.
echo [INFO] Running dbt with target: %DBT_TARGET%
echo.

REM Run the SCD Update mapping
echo [STEP 1/1] Running mapping: m_SIL_UserDimension_Update
dbt run --select m_SIL_UserDimension_Update --target %DBT_TARGET%

IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] m_SIL_UserDimension_Update failed with error code %ERRORLEVEL%
    echo [ERROR] Workflow WF_SIL_UserDimension_Update FAILED
    exit /b %ERRORLEVEL%
)

echo.
echo [STEP 1/1] COMPLETED: m_SIL_UserDimension_Update
echo.

echo =====================================================================
echo Workflow WF_SIL_UserDimension_Update completed successfully
echo Timestamp: %DATE% %TIME%
echo =====================================================================
