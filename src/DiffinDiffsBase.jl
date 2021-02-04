module DiffinDiffsBase

using CSV: File
using Combinatorics: combinations
using MacroTools: @capture, isexpr, postwalk
using Missings: disallowmissing
using Reexport
using SplitApplyCombine: groupfind, groupview
using StatsBase: Weights, uweights
@reexport using StatsModels
using Tables: istable, getcolumn, columntable

import Base: ==, show, union
import Base: eltype, firstindex, lastindex, getindex, iterate, length, sym_in
import StatsModels: termvars

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

       Terms,
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
       CheckVars,
       MakeWeights,

       DiffinDiffsEstimator,
       DefaultDID,
       did,
       didspec,
       @did,
       DIDResult

include("utils.jl")
include("treatments.jl")
include("parallels.jl")
include("terms.jl")
include("StatsProcedures.jl")
include("procedures.jl")
include("did.jl")

end
