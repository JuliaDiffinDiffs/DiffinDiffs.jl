# Define simple generic types and methods for testing

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

struct NotImplemented <: DiffinDiffsEstimator end
struct TestDID <: DiffinDiffsEstimator end

const TR = TestTreatment(:t, 0)
const PR = TestParallel(0)
