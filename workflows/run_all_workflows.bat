@echo off
REM =====================================================================
REM MASTER ORCHESTRATION: Run All User Dimension Workflows
REM Equivalent to: Informatica Workflow Chain or Scheduler Job
REM 
REM This script runs all workflows in the correct order:
REM   1. WF_SDE_ORA_UserDimension  - Extract from source to staging
REM   2. WF_SIL_UserDimension      - Load staging to dimension
REM   3. WF_SIL_UserDimension_Update - SCD Type 2 close old records
REM
REM Usage:
REM   run_all_workflows.bat [target]
REM   
REM   Examples:
REM     run_all_workflows.bat          - Uses default target (dev)
REM     run_all_workflows.bat prod     - Uses prod target
REM =====================================================================

echo.
echo =====================================================================
echo          USER DIMENSION ETL PIPELINE - MASTER ORCHESTRATION
echo =====================================================================
echo.
echo Start Time: %DATE% %TIME%
echo.

REM Navigate to dbt project directory
cd /d "%~dp0.."

REM Set target from argument or default to dev
IF "%1"=="" (
    SET DBT_TARGET=dev
) ELSE (
    SET DBT_TARGET=%1
)

echo [CONFIG] DBT Target: %DBT_TARGET%
echo [CONFIG] Project Dir: %CD%
echo.

REM =====================================================================
REM STEP 1: Extract (SDE)
REM =====================================================================
echo.
echo #####################################################################
echo # STEP 1 of 3: WF_SDE_ORA_UserDimension (Extract)
echo #####################################################################
echo.

call "%~dp0WF_SDE_ORA_UserDimension.bat"
IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo ! PIPELINE FAILED at Step 1: WF_SDE_ORA_UserDimension
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo.
    echo End Time: %DATE% %TIME%
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] Step 1 completed: WF_SDE_ORA_UserDimension
echo.

REM =====================================================================
REM STEP 2: Load (SIL)
REM =====================================================================
echo.
echo #####################################################################
echo # STEP 2 of 3: WF_SIL_UserDimension (Load)
echo #####################################################################
echo.

call "%~dp0WF_SIL_UserDimension.bat"
IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo ! PIPELINE FAILED at Step 2: WF_SIL_UserDimension
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo.
    echo End Time: %DATE% %TIME%
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] Step 2 completed: WF_SIL_UserDimension
echo.

REM =====================================================================
REM STEP 3: SCD Update
REM =====================================================================
echo.
echo #####################################################################
echo # STEP 3 of 3: WF_SIL_UserDimension_Update (SCD Type 2)
echo #####################################################################
echo.

call "%~dp0WF_SIL_UserDimension_Update.bat"
IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo ! PIPELINE FAILED at Step 3: WF_SIL_UserDimension_Update
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo.
    echo End Time: %DATE% %TIME%
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] Step 3 completed: WF_SIL_UserDimension_Update
echo.

REM =====================================================================
REM PIPELINE COMPLETED
REM =====================================================================
echo.
echo =====================================================================
echo          ALL WORKFLOWS COMPLETED SUCCESSFULLY
echo =====================================================================
echo.
echo Summary:
echo   [OK] WF_SDE_ORA_UserDimension  - Extract completed
echo   [OK] WF_SIL_UserDimension      - Load completed
echo   [OK] WF_SIL_UserDimension_Update - SCD Update completed
echo.
echo End Time: %DATE% %TIME%
echo =====================================================================
