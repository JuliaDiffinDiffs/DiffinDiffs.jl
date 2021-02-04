# Define simple generic types and methods for testing

import Base: show

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

testresult(::AbstractTreatment, ::String) = ((result="testresult",), false)
const TestResult = StatsStep{:TestResult, typeof(testresult)}
required(::TestResult) = (:tr, :str)

const TestDID = DiffinDiffsEstimator{:TestDID, Tuple{TestStep,TestResult}}
const NotImplemented = DiffinDiffsEstimator{:NotImplemented, Tuple{}}

const TR = TestTreatment(:t, 0)
const PR = TestParallel(0)
