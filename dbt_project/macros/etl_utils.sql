{% macro etl_metadata() %}
{#-
    Macro to generate standard ETL metadata columns
    Equivalent to Informatica EXP_ORA_ETL_METADATA expression transformation
    
    Returns:
        SQL fragment with standard ETL metadata columns
-#}
    {{ var('datasource_num_id') }} AS datasource_num_id,
    CURRENT_TIMESTAMP AS w_insert_dt,
    CURRENT_TIMESTAMP AS w_update_dt,
    '{{ invocation_id }}' AS etl_proc_wid
{% endmacro %}


{% macro incremental_filter(timestamp_column, last_extract_var='last_extract_date') %}
{#-
    Macro for incremental load filtering
    Equivalent to Informatica $$LAST_EXTRACT_DATE parameter usage
    
    Args:
        timestamp_column: Column to filter on
        last_extract_var: Variable name for last extract date
        
    Returns:
        SQL WHERE clause fragment for incremental filtering
-#}
    {% if is_incremental() %}
        {{ timestamp_column }} > CAST('{{ var(last_extract_var) }}' AS TIMESTAMP)
    {% else %}
        1=1
    {% endif %}
{% endmacro %}
