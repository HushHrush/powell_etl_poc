@echo off
REM =====================================================================
REM WORKFLOW: WF_SDE_ORA_UserDimension
REM Description: Extract user data from Oracle EBS to staging
REM Equivalent to: Informatica Workflow WF_SDE_ORA_UserDimension
REM 
REM Mapping(s) Called:
REM   - m_SDE_ORA_UserDimension
REM
REM Source Tables:
REM   - ORACLE_APPS.FND_USER
REM   - ORACLE_APPS.PER_ALL_PEOPLE_F
REM   - ORACLE_APPS.ORG_ORGANIZATION_DEFINITIONS
REM   - ORACLE_APPS.GL_SETS_OF_BOOKS
REM
REM Target Table:
REM   - DATA_WAREHOUSE.W_USER_DS
REM =====================================================================

echo =====================================================================
echo Starting Workflow: WF_SDE_ORA_UserDimension
echo Timestamp: %DATE% %TIME%
echo =====================================================================

REM Navigate to dbt project directory
cd /d "%~dp0.."

REM Set environment (can be overridden)
IF "%DBT_TARGET%"=="" SET DBT_TARGET=dev

echo.
echo [INFO] Running dbt with target: %DBT_TARGET%
echo.

REM Run the SDE mapping
echo [STEP 1/2] Running mapping: m_SDE_ORA_UserDimension
dbt run --select m_SDE_ORA_UserDimension --target %DBT_TARGET%

IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] m_SDE_ORA_UserDimension failed with error code %ERRORLEVEL%
    echo [ERROR] Workflow WF_SDE_ORA_UserDimension FAILED
    exit /b %ERRORLEVEL%
)

echo.
echo [STEP 1/2] COMPLETED: m_SDE_ORA_UserDimension
echo.

REM Run tests for the mapping
echo [STEP 2/2] Running tests for: m_SDE_ORA_UserDimension
dbt test --select m_SDE_ORA_UserDimension --target %DBT_TARGET%

IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo [WARNING] Tests for m_SDE_ORA_UserDimension had failures
    echo [WARNING] Review test results before proceeding
)

echo.
echo =====================================================================
echo Workflow WF_SDE_ORA_UserDimension completed successfully
echo Timestamp: %DATE% %TIME%
echo =====================================================================
