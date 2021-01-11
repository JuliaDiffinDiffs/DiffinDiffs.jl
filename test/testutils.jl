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

const NotImplemented = DiffinDiffsEstimator{Tuple{typeof(println)}}
show(io::IO, d::Type{NotImplemented}) = print(io, "NotImplemented")

const TestDID = DiffinDiffsEstimator{Tuple{typeof(print), typeof(println)}}
show(io::IO, d::Type{TestDID}) = print(io, "TestDID")

const TR = TestTreatment(:t, 0)
const PR = TestParallel(0)
