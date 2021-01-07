module DiffinDiffsBase

using CSV
using Reexport
using StatsBase
@reexport using StatsModels

import Base: ==, show

export @fieldequal,
       eachterm,
       c,
       unpack,
       kwarg,
       @unpack,
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

       TreatmentTerm,
       treat,
       hastreat,
       parse_treat,

       AbstractDiffinDiffs,
       did,
       DIDSpec,
       spec,
       @spec,
       @did,
       DIDSpecSet,
       DIDResult,
       agg,
       AggregatedDIDResult

include("utils.jl")
include("treatments.jl")
include("parallels.jl")
include("terms.jl")
include("did.jl")

end
