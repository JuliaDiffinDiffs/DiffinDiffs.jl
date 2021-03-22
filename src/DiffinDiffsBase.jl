module DiffinDiffsBase

using CSV
using CodecZlib: GzipDecompressorStream
using Combinatorics: combinations
using DataAPI: refarray, refpool
using MacroTools: @capture, isexpr, postwalk
using Missings: disallowmissing
using PooledArrays: _label
using Reexport
using StatsBase: Weights, uweights
@reexport using StatsModels
using StatsModels: Schema
using Tables
using Tables: AbstractColumns, table, istable, columnnames, getcolumn

import Base: ==, show, union
import Base: eltype, firstindex, lastindex, getindex, iterate, length, sym_in
import StatsBase: coef, vcov, responsename, coefnames, weights, nobs, dof_residual
import StatsModels: concrete_term, schema, termvars

const TimeType = Int

# Reexport objects from StatsBase
export coef, vcov, responsename, coefnames, weights, nobs, dof_residual

export cb,
       ≊,
       exampledata,

       VecColumnTable,
       VecColsRow,
       subcolumns,

       TreatmentSharpness,
       SharpDesign,
       sharp,
       AbstractTreatment,
       DynamicTreatment,
       dynamic,

       ParallelCondition,
       Unconditional,
       unconditional,
       CovariateConditional,
       ParallelStrength,
       Exact,
       exact,
       Approximate,
       AbstractParallel,
       TrendParallel,
       NeverTreatedParallel,
       nevertreated,
       NotYetTreatedParallel,
       notyettreated,
       istreated,

       TermSet,
       termset,
       eachterm,
       TreatmentTerm,
       treat,

       findcell,
       cellrows,

       StatsStep,
       AbstractStatsProcedure,
       SharedStatsStep,
       PooledStatsProcedure,
       StatsSpec,
       proceed,
       @specset,

       CheckData,
       GroupTerms,
       CheckVars,
       MakeWeights,

       DiffinDiffsEstimator,
       DefaultDID,
       did,
       didspec,
       @did,
       DIDResult,
       outcomename,
       treatnames

include("utils.jl")
include("tables.jl")
include("treatments.jl")
include("parallels.jl")
include("terms.jl")
include("operations.jl")
include("StatsProcedures.jl")
include("procedures.jl")
include("did.jl")

end
