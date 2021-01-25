module DiffinDiffsBase

using Combinatorics: combinations
using CSV: File
using MacroTools: @capture, isexpr, postwalk
using Reexport
using StatsBase
@reexport using StatsModels
using StatsModels: TupleTerm
using SplitApplyCombine: groupfind, groupview
using Tables: columntable, istable, rows, columns, getcolumn

import Base: ==, show, union
import Base: eltype, firstindex, lastindex, getindex, iterate, length, sym_in

import StatsModels: termvars

export TupleTerm

export @fieldequal,
       eachterm,
       c,
       unpack,
       kwarg,
       @unpack,
       ≊,
       exampledata,

       EleOrVec,
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
       treated,

       TreatmentTerm,
       treat,
       hastreat,
       parse_treat,

       StatsStep,
       namedargs,
       AbstractStatsProcedure,
       SharedStatsStep,
       PooledStatsProcedure,
       pool,
       StatsSpec,
       @specset,
       proceed,

       CheckData,
       CheckVars,

       DiffinDiffsEstimator,
       DefaultDID,
       did,
       didspec,
       @didspec,
       @did,
       DIDResult,
       agg,
       AggregatedDIDResult

include("utils.jl")
include("treatments.jl")
include("parallels.jl")
include("terms.jl")
include("StatsProcedures.jl")
include("procedures.jl")
include("did.jl")

end
