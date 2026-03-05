{% macro get_master_code(category, source_code) %}
{#-
    Macro to lookup master code from W_CODE_D dimension
    Equivalent to Informatica Lookup transformations (LKP_CODES_*)
    
    Args:
        category: Code category (e.g., 'GENDER', 'STATE', 'COUNTRY')
        source_code: The source code value to lookup
        
    Returns:
        master_code value or configured default if not found
-#}
    COALESCE(
        (SELECT master_code 
         FROM {{ source('warehouse', 'w_code_d') }} 
         WHERE category = '{{ category }}'
           AND source_code = {{ source_code }}
           AND datasource_num_id = {{ var('datasource_num_id') }}
           AND language_code = {{ var('language_code') }}
         LIMIT 1),
        CASE 
            WHEN {{ source_code }} IS NULL THEN {{ var('source_code_not_supplied') }}
            ELSE {{ var('master_code_not_found') }}
        END
    )
{% endmacro %}


{% macro get_master_value(category, source_code) %}
{#-
    Macro to lookup master value (description) from W_CODE_D dimension
    
    Args:
        category: Code category (e.g., 'GENDER', 'STATE', 'COUNTRY')
        source_code: The source code value to lookup
        
    Returns:
        master_value (description) or configured default if not found
-#}
    COALESCE(
        (SELECT master_value 
         FROM {{ source('warehouse', 'w_code_d') }} 
         WHERE category = '{{ category }}'
           AND source_code = {{ source_code }}
           AND datasource_num_id = {{ var('datasource_num_id') }}
           AND language_code = {{ var('language_code') }}
         LIMIT 1),
        CASE 
            WHEN {{ source_code }} IS NULL THEN {{ var('source_code_not_supplied') }}
            ELSE {{ var('master_code_not_found') }}
        END
    )
{% endmacro %}
