# Define simple generic types and methods for testing

sprintcompact(x) = sprint(show, x; context=:compact=>true)

struct TestSharpness <: TreatmentSharpness end
struct TestParaCondition <: ParallelCondition end
struct TestParaStrength <: ParallelStrength end

struct TestTreatment <: AbstractTreatment
    time::Symbol
    ref::Int
end

ttreat(time::Term, ref::ConstantTerm) = TestTreatment(time.sym, ref.n)

struct TestParallel{C,S} <: AbstractParallel{C,S}
    e::Int
end

TestParallel(e::Int) = TestParallel{ParallelCondition,ParallelStrength}(e)
tpara(c::ConstantTerm) = TestParallel{ParallelCondition,ParallelStrength}(c.n)

teststep(tr::AbstractTreatment, pr::AbstractParallel) =
    ((str=sprint(show, tr), spr=sprint(show, pr)), false)
const TestStep = StatsStep{:TestStep, typeof(teststep)}
required(::TestStep) = (:tr, :pr)

testnextstep(::AbstractTreatment, str::String) = ((next="next"*str,), false)
const TestNextStep = StatsStep{:TestNextStep, typeof(testnextstep)}
required(::TestNextStep) = (:tr, :str)

const TestDID = DiffinDiffsEstimator{:TestDID, Tuple{TestStep,TestNextStep}}
const NotImplemented = DiffinDiffsEstimator{:NotImplemented, Tuple{}}

const TR = TestTreatment(:t, 0)
const PR = TestParallel(0)

struct TestResult <: DIDResult
    coef::Vector{Float64}
    vcov::Matrix{Float64}
    nobs::Int
    dof_residual::Int
    yname::String
    coefnames::Vector{String}
    coefinds::Dict{String, Int}
    treatinds::Table
    weightname::Symbol
end

@fieldequal TestResult

function TestResult(n1::Int, n2::Int)
    N = n1*(n2+1)
    coef = collect(Float64, 1:N)
    tnames = ["rel: $a & c: $b" for a in 1:n1 for b in 1:n2]
    cnames = vcat(tnames, ["c"*string(i) for i in n1*n2+1:N])
    cinds = Dict(cnames .=> 1:N)
    tinds = Table((rel=repeat(1:n1, inner=n2), c=repeat(1:n2, outer=n1)))
    return TestResult(coef, coef.*coef', N, N-1, "y", cnames, cinds, tinds, :w)
end

function result(::Type{TestDID}, nt::NamedTuple)
    return merge(nt, (result=TestResult(2, 2),))
end
