# Informatica to dbt Conversion Project

This dbt project contains Informatica PowerCenter mappings converted to dbt models for the User Dimension (W_USER_D).

## Project Structure

```
dbt_project/
├── dbt_project.yml              # Project configuration
├── models/
│   ├── sources.yml              # Source table definitions
│   └── mappings/                # Informatica mappings converted to dbt
│       ├── m_SDE_ORA_UserDimension.sql      # Extract mapping
│       ├── m_SIL_UserDimension.sql          # Load mapping with lookups
│       ├── m_SIL_UserDimension_Update.sql   # SCD Type 2 update mapping
│       └── schema.yml                        # Model documentation & tests
├── macros/                      # Reusable SQL macros
│   ├── code_lookups.sql         # Code lookup utilities
│   ├── scd2_helpers.sql         # SCD Type 2 helper macros
│   └── etl_utils.sql            # ETL utility macros
└── workflows/                   # Orchestration scripts (like Informatica workflows)
    ├── WF_SDE_ORA_UserDimension.bat
    ├── WF_SIL_UserDimension.bat
    ├── WF_SIL_UserDimension_Update.bat
    └── run_all_workflows.bat
```

## Informatica to dbt Mapping

| Informatica Mapping | dbt Model | Description |
|---------------------|-----------|-------------|
| m_SDE_ORA_UserDimension | `m_SDE_ORA_UserDimension.sql` | Extract from Oracle EBS to staging (W_USER_DS) |
| m_SIL_UserDimension | `m_SIL_UserDimension.sql` | Load to dimension with code lookups (W_USER_D) |
| m_SIL_UserDimension_Update | `m_SIL_UserDimension_Update.sql` | SCD Type 2 - close old records |

| Informatica Workflow | dbt Workflow | Description |
|---------------------|--------------|-------------|
| WF_SDE_ORA_UserDimension | `WF_SDE_ORA_UserDimension.bat` | Run extract mapping |
| WF_SIL_UserDimension | `WF_SIL_UserDimension.bat` | Run load mapping |
| WF_SIL_UserDimension_Update | `WF_SIL_UserDimension_Update.bat` | Run SCD update mapping |

## Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `datasource_num_id` | 1 | Source system identifier |
| `language_code` | 'E' | Language code for lookups |
| `last_extract_date` | '1900-01-01 00:00:00' | Incremental load cutoff |
| `default_eff_from_date` | '1899-01-01' | Default effective from date |
| `default_eff_to_date` | '4712-12-31' | Default effective to date (high date) |

## Running the Models

### Option 1: Using Workflow Scripts
```batch
# Run individual workflow
workflows\WF_SDE_ORA_UserDimension.bat

# Run full ETL pipeline
workflows\run_all_workflows.bat
```

### Option 2: Using dbt Commands
```bash
# Run specific mapping
dbt run --select m_SDE_ORA_UserDimension

# Run all SDE mappings
dbt run --select tag:SDE

# Run all SIL mappings
dbt run --select tag:SIL

# Run full pipeline with dependencies
dbt run --select +m_SIL_UserDimension_Update

# Run tests
dbt test --select tag:UserDimension
```

## Source Tables

**Oracle EBS (ORACLE_APPS schema):**
- `FND_USER` - User accounts
- `PER_ALL_PEOPLE_F` - Person details (date effective)
- `ORG_ORGANIZATION_DEFINITIONS` - Organization definitions
- `GL_SETS_OF_BOOKS` - Ledger information

**Data Warehouse (DATA_WAREHOUSE schema):**
- `W_USER_D` - User Dimension (target)
- `W_USER_DS` - User Dimension Staging
- `W_CODE_D` - Code lookup table

## Setup

1. Configure your Snowflake connection in `~/.dbt/profiles.yml`:
```yaml
snowflake:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: your_account
      user: your_user
      password: your_password
      role: your_role
      warehouse: your_warehouse
      database: your_database
      schema: DATA_WAREHOUSE
```

2. Set environment variable (optional):
```batch
set SNOWFLAKE_DATABASE=your_database
```

3. Run the pipeline:
```batch
cd dbt_project
dbt deps
workflows\run_all_workflows.bat
```
