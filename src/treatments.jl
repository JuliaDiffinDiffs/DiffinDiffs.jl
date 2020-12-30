"""
    AbstractTreatment

Supertype for all treatment types.
"""
abstract type AbstractTreatment end

@fieldequal AbstractTreatment

"""
    DynamicTreatment <: AbstractTreatment

Supertype for all treatment types with a field `time::Symbol`
that stores the column name of data representing calendar time.
"""
abstract type DynamicTreatment <: AbstractTreatment end

function dynamic end
