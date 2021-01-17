using DiffinDiffsBase: _f, _specnames, _tracenames,
    _share, _sharedby

testvoidstep(a::String, b::String) = println(a)
const TestVoidStep = StatsStep{typeof(testvoidstep), (:a, :b), ()}
@show_StatsStep TestVoidStep "TestVoidStep"

testregstep(a::String, b::String) = (b=a, c=a*b,)
const TestRegStep = StatsStep{typeof(testregstep), (:a, :b), ()}
@show_StatsStep TestRegStep "TestRegStep"

testlaststep(a::String, c::String) = (result=a*c,)
const TestLastStep = StatsStep{typeof(testlaststep), (:a,), (:c,)}
@show_StatsStep TestLastStep "TestLastStep"

testinvalidstep(a::String, b::String) = b
const TestInvalidStep = StatsStep{typeof(testinvalidstep), (:a,:b), ()}
@show_StatsStep TestInvalidStep "TestInvalidStep"

@testset "StatsStep" begin
    @testset "TestVoidStep" begin
        @test sprint(show, TestVoidStep()) == """
        StatsStep: TestVoidStep
          arguments from StatsSpec: (:a, :b)
          arguments from trace: ()"""
        @test sprintcompact(TestVoidStep()) == "TestVoidStep"

        @test _f(TestVoidStep()) == testvoidstep
        @test _specnames(TestVoidStep()) == (:a, :b)
        @test _tracenames(TestVoidStep()) == ()

        @test TestVoidStep()((a="a", b="b")) == (a="a", b="b")
    end

    @testset "TestRegStep" begin
        @test sprint(show, TestRegStep()) == """
        StatsStep: TestRegStep
          arguments from StatsSpec: (:a, :b)
          arguments from trace: ()"""
        @test sprintcompact(TestRegStep()) == "TestRegStep"

        @test _f(TestRegStep()) == testregstep
        @test _specnames(TestRegStep()) == (:a, :b)
        @test _tracenames(TestRegStep()) == ()

        @test TestRegStep()((a="a", b="b")) == (a="a", b="a", c="ab")
    end

    @testset "TestLastStep" begin
        @test sprint(show, TestLastStep()) == """
        StatsStep: TestLastStep
          arguments from StatsSpec: (:a,)
          arguments from trace: (:c,)"""
        @test sprintcompact(TestLastStep()) == "TestLastStep"

        @test _f(TestLastStep()) == testlaststep
        @test _specnames(TestLastStep()) == (:a,)
        @test _tracenames(TestLastStep()) == (:c,)

        @test TestLastStep()((a="a", b="a", c="ab")) == (a="a", b="a", c="ab", result="aab")
    end

    @testset "TestInvalidStep" begin
        @test_throws ErrorException TestInvalidStep()((a="a", b="a", c="ab"))
        @test_throws ErrorException TestInvalidStep()((a="a",))
    end
end

struct TestProcedure{T} <: AbstractStatsProcedure{T} end
const TP = TestProcedure{Tuple{TestVoidStep,TestRegStep,TestLastStep}}
const tp = TP()

@testset "procedures" begin
    @testset "AbstractStatsProcedure" begin
        @test length(tp) == 3
        @test eltype(AbstractStatsProcedure) == StatsStep
        @test eltype(TP) == StatsStep
        @test firstindex(tp) == 1
        @test tp[begin] == TestVoidStep()
        @test lastindex(tp) == 3
        @test tp[end] == TestLastStep()
        @test tp[1] == TestVoidStep()
        @test tp[2:-1:1] == [TestRegStep(), TestVoidStep()]
        @test tp[[2,3]] == [TestRegStep(), TestLastStep()]
        @test_throws BoundsError tp[4]
        @test iterate(tp) == (TestVoidStep(), 2)
        @test iterate(tp, 2) == (TestRegStep(), 3)
        @test iterate(tp, 4) === nothing
    end

    @testset "SharedStatsStep" begin
        s1 = SharedStatsStep{TestRegStep,(1,)}(TestRegStep())
        s2 = SharedStatsStep{TestRegStep,(2,3,)}(TestRegStep())
        @test _share(TestRegStep(), 1) == s1
        @test _share(TestRegStep(), [2,3]) == s2
        @test _sharedby(s1) == (1,)
        @test _sharedby(s2) == (2,3,)
        @test _f(s1) == testregstep
        @test _specnames(s1) == (:a, :b)
        @test _tracenames(s1) == ()
    end

    @testset "PooledStatsProcedure" begin
        ps = (tp,)
        shared = (Vector{SharedStatsStep}(undef, 3),)
        shared[1] .= _share.(collect(tp), 1)
        p1 = pool(tp)
        @test p1 == PooledStatsProcedure{typeof(ps), typeof(shared), 3}(ps, shared)
        @test length(p1) == 3
        @test eltype(PooledStatsProcedure) == SharedStatsStep

        @test iterate(p1) == (shared[1][1], (shared[1][2:3],))
        @test iterate(p1, (shared[1][2:3],)) == (shared[1][2], (shared[1][[3]],))

        ps = (tp, tp)
        shared = (Vector{SharedStatsStep}(undef, 3),Vector{SharedStatsStep}(undef, 3))
        shared[1] .= _share.(collect(tp), Ref((1,2)))
        shared[2] .= _share.(collect(tp), Ref((1,2)))
        p2 = pool(tp, tp)
        @test p2 == PooledStatsProcedure{typeof(ps), typeof(shared), 3}(ps, shared)
        @test length(p2) == 3
    end
end

