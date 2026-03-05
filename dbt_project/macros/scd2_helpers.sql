{% macro generate_scd2_dates(effective_from_dt, is_new_record) %}
{#-
    Macro to generate SCD Type 2 effective dates
    Equivalent to Informatica EXP_SCD2_DATES expression transformation
    
    Args:
        effective_from_dt: The effective from date from source
        is_new_record: Boolean flag indicating if this is a new record
        
    Returns:
        SQL CASE expression for effective dates
-#}
    CASE 
        WHEN {{ is_new_record }} THEN CURRENT_TIMESTAMP
        ELSE {{ effective_from_dt }}
    END
{% endmacro %}


{% macro generate_scd2_row_wid() %}
{#-
    Macro to generate surrogate key for dimension records
    Equivalent to Informatica Seq_W_USER_D_Wid sequence generator
    
    Returns:
        ROW_NUMBER() expression for generating unique row_wid
-#}
    ROW_NUMBER() OVER (ORDER BY integration_id, effective_from_dt)
{% endmacro %}


{% macro scd2_current_flg(effective_to_dt) %}
{#-
    Macro to determine if record is current based on effective_to_dt
    
    Args:
        effective_to_dt: The effective to date
        
    Returns:
        'Y' if record is current, 'N' otherwise
-#}
    CASE 
        WHEN {{ effective_to_dt }} >= CAST('{{ var("default_eff_to_date") }}' AS DATE) THEN 'Y'
        ELSE 'N'
    END
{% endmacro %}
