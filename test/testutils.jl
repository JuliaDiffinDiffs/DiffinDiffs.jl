# Define simple generic types for testing

struct TestTreatment <: AbstractTreatment
    time::Symbol
    ref::Int
end

testtreat(time::Term, ref::ConstantTerm) = TestTreatment(time.sym, ref.n)

struct TestParallel{C,S} <: AbstractParallel{C,S}
    e::Int
end

TestParallel(e::Int) = TestParallel{ParallelCondition,ParallelStrength}(e)
testpara(c::ConstantTerm) = TestParallel{ParallelCondition,ParallelStrength}(c.n)
