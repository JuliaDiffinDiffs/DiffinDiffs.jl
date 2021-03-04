module DiffinDiffsBase

using CSV: File
using Combinatorics: combinations
using MacroTools: @capture, isexpr, postwalk
using Missings: disallowmissing
using Reexport
using StatsBase: Weights, uweights
@reexport using StatsModels
using Tables: istable, getcolumn, columntable, columnnames

import Base: ==, show, union
import Base: eltype, firstindex, lastindex, getindex, iterate, length, sym_in
import StatsBase: coef, vcov, responsename, coefnames, weights, nobs, dof_residual
import StatsModels: termvars

const TimeType = Int

# Reexport objects from StatsBase
export coef, vcov, responsename, coefnames, weights, nobs, dof_residual

export cb,
       ≊,
       exampledata,

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
       eachterm,
       TreatmentTerm,
       treat,

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
include("treatments.jl")
include("parallels.jl")
include("terms.jl")
include("StatsProcedures.jl")
include("procedures.jl")
include("did.jl")

end
