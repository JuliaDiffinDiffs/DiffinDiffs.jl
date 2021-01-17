# Define simple generic types and methods for testing

import Base: show

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
    (str=sprint(show, tr), spr=sprint(show, pr))
const TestStep = StatsStep{typeof(teststep), (:tr, :pr), ()}
@show_StatsStep TestStep "TestStep"

testresult(::AbstractTreatment, ::String) = (result="testresult",)
const TestResult = StatsStep{typeof(testresult), (:tr,), (:str,)}
@show_StatsStep TestResult "TestResult"

const NotImplemented = DiffinDiffsEstimator{Tuple{TestStep}}
show(io::IO, d::Type{NotImplemented}) = print(io, "NotImplemented")

const TestDID = DiffinDiffsEstimator{Tuple{TestStep,TestResult}}
show(io::IO, d::Type{TestDID}) = print(io, "TestDID")

const TR = TestTreatment(:t, 0)
const PR = TestParallel(0)
