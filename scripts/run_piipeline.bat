@echo off
setlocal
cd /d "D:\Data-Eng\Project\Credit-Risk-Pipeline"

echo Pipeline Start!

python -m src.phase1_ingestion.push_data_to_pgsql
if %ERRORLEVEL% neq 0 ( echo FAILED Step 1 & exit /b 1 )
echo SUCCESS Step 1

python -m src.phase1_ingestion.load_fx_rate
if %ERRORLEVEL% neq 0 ( echo FAILED Step 2 & exit /b 1 )
echo SUCCESS Step 2

python -m src.phase2_transformation.bronze_transform
if %ERRORLEVEL% neq 0 ( echo FAILED Step 3 & exit /b 1 )
echo SUCCESS Step 3

python -m src.phase2_transformation.silver_transform
if %ERRORLEVEL% neq 0 ( echo FAILED Step 4 & exit /b 1 )
echo SUCCESS Step 4

python -m src.phase2_transformation.gold_aggregate
if %ERRORLEVEL% neq 0 ( echo FAILED Step 5 & exit /b 1 )
echo SUCCESS Step 5

python -m src.quality.data_quality
if %ERRORLEVEL% neq 0 ( echo FAILED Step 6 & exit /b 1 )
echo SUCCESS Step 6

python -m src.reconciliation.reconciliation
if %ERRORLEVEL% neq 0 ( echo FAILED Step 7 & exit /b 1 )
echo SUCCESS Step 7

echo All Pipelines Completed!
endlocal