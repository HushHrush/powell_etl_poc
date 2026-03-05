@echo off
REM =====================================================================
REM WORKFLOW: WF_SIL_UserDimension
REM Description: Load staging to dimension with SCD Type 2
REM Equivalent to: Informatica Workflow WF_SIL_UserDimension
REM 
REM Mapping(s) Called:
REM   - m_SIL_UserDimension
REM
REM Source Tables:
REM   - DATA_WAREHOUSE.W_USER_DS (from m_SDE_ORA_UserDimension)
REM   - DATA_WAREHOUSE.W_CODE_D (lookup table)
REM
REM Target Table:
REM   - DATA_WAREHOUSE.W_USER_D
REM =====================================================================

echo =====================================================================
echo Starting Workflow: WF_SIL_UserDimension
echo Timestamp: %DATE% %TIME%
echo =====================================================================

REM Navigate to dbt project directory
cd /d "%~dp0.."

REM Set environment (can be overridden)
IF "%DBT_TARGET%"=="" SET DBT_TARGET=dev

echo.
echo [INFO] Running dbt with target: %DBT_TARGET%
echo.

REM Check if upstream model exists
echo [PRE-CHECK] Verifying upstream model m_SDE_ORA_UserDimension exists...
dbt ls --select m_SDE_ORA_UserDimension --target %DBT_TARGET% >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Upstream model may not exist. Running full dependency chain...
    dbt run --select +m_SIL_UserDimension --target %DBT_TARGET%
) ELSE (
    REM Run the SIL mapping only
    echo [STEP 1/2] Running mapping: m_SIL_UserDimension
    dbt run --select m_SIL_UserDimension --target %DBT_TARGET%
)

IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] m_SIL_UserDimension failed with error code %ERRORLEVEL%
    echo [ERROR] Workflow WF_SIL_UserDimension FAILED
    exit /b %ERRORLEVEL%
)

echo.
echo [STEP 1/2] COMPLETED: m_SIL_UserDimension
echo.

REM Run tests for the mapping
echo [STEP 2/2] Running tests for: m_SIL_UserDimension
dbt test --select m_SIL_UserDimension --target %DBT_TARGET%

IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo [WARNING] Tests for m_SIL_UserDimension had failures
    echo [WARNING] Review test results before proceeding
)

echo.
echo =====================================================================
echo Workflow WF_SIL_UserDimension completed successfully
echo Timestamp: %DATE% %TIME%
echo =====================================================================
