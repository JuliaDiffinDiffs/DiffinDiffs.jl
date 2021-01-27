module DiffinDiffsBase

using Combinatorics: combinations
using CSV: File
using MacroTools: @capture, isexpr, postwalk
using Reexport
@reexport using StatsModels
using StatsModels: TupleTerm
using SplitApplyCombine: groupfind, groupview
using Tables: istable, getcolumn

import Base: ==, show, union
import Base: eltype, firstindex, lastindex, getindex, iterate, length, sym_in
import StatsModels: termvars

export TupleTerm

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

       TreatmentTerm,
       treat,

       StatsStep,
       namedargs,
       AbstractStatsProcedure,
       SharedStatsStep,
       PooledStatsProcedure,
       pool,
       StatsSpec,
       proceed,
       @specset,

       CheckData,
       CheckVars,

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
