using DiffinDiffsBase: _f, _getargs, _update,
    _sharedby, _show_args, _args_kwargs, _parse_kwargs!, _spec_walker, proceed

testvoidstep(a::String) = nothing
const TestVoidStep = StatsStep{:TestVoidStep, typeof(testvoidstep)}
namedargs(::TestVoidStep) = (a="a",)

testregstep(a::String, b::String) = (c=a*b,)
const TestRegStep = StatsStep{:TestRegStep, typeof(testregstep)}
namedargs(::TestRegStep) = (a="a", b="b")

testlaststep(a::String, c::String) = (result=a*c,)
const TestLastStep = StatsStep{:TestLastStep, typeof(testlaststep)}
namedargs(::TestLastStep) = (a="a", c="b")

testinvalidstep(a::String, b::String) = b
const TestInvalidStep = StatsStep{:TestInvalidStep, typeof(testinvalidstep)}
namedargs(::TestInvalidStep) = (a=nothing, b=nothing)

@testset "StatsStep" begin
    @testset "TestVoidStep" begin
        @test sprint(show, TestVoidStep()) == "TestVoidStep"
        @test sprint(show, MIME("text/plain"), TestVoidStep()) ==
            "TestVoidStep (StatsStep that calls testvoidstep)"

        @test _f(TestVoidStep()) == testvoidstep
        @test TestVoidStep()((a="a", b="b")) == (a="a", b="b")
    end

    @testset "TestRegStep" begin
        @test sprint(show, TestRegStep()) == "TestRegStep"
        @test sprint(show, MIME("text/plain"), TestRegStep()) ==
            "TestRegStep (StatsStep that calls testregstep)"

        @test _f(TestRegStep()) == testregstep
        @test TestRegStep()() == (c="ab",)
        @test TestRegStep()((a="c", b="d")) == (a="c", b="d", c="cd")
    end

    @testset "TestLastStep" begin
        @test sprint(show, TestLastStep()) == "TestLastStep"
        @test sprint(show, MIME("text/plain"), TestLastStep()) ==
            "TestLastStep (StatsStep that calls testlaststep)"
        
        @test _f(TestLastStep()) == testlaststep
        @test TestLastStep()((a="a", b="a", c="ab")) ==
            (a="a", b="a", c="ab", result="aab")
    end

    @testset "TestInvalidStep" begin
        @test_throws ErrorException TestInvalidStep()((a="a", b="a", c="ab"))
        @test_throws MethodError TestInvalidStep()((a="a",))
    end
end

struct TestProcedure{A,T} <: AbstractStatsProcedure{A,T} end
const RP = TestProcedure{:RegProcedure,Tuple{TestVoidStep,TestRegStep,TestLastStep}}
const rp = RP()
const IP = TestProcedure{:InverseProcedure,Tuple{TestRegStep,TestVoidStep,TestLastStep}}
const ip = IP()
const UP = TestProcedure{:UnitProcedure,Tuple{TestRegStep}}
const up = UP()
const NP = TestProcedure{:NullProcedure,Tuple{}}
const np = NP()

@testset "AbstractStatsProcedure" begin
    @test length(rp) == 3
    @test eltype(AbstractStatsProcedure) == StatsStep
    @test eltype(RP) == StatsStep

    @test firstindex(rp) == 1
    @test lastindex(rp) == 3
    @test rp[end] == TestLastStep()
    @test rp[1] == TestVoidStep()
    @test rp[2:-1:1] == [TestRegStep(), TestVoidStep()]
    @test rp[[2,3]] == [TestRegStep(), TestLastStep()]
    @test_throws BoundsError rp[4]

    @test iterate(rp) == (TestVoidStep(), 2)
    @test iterate(rp, 2) == (TestRegStep(), 3)
    @test iterate(rp, 4) === nothing

    @test length(np) == 0
    @test eltype(NP) == StatsStep
    @test_throws BoundsError np[1]
    @test iterate(np) === nothing

    @test sprint(show, rp) == "RegProcedure"
    @test sprint(show, MIME("text/plain"), rp) == """
        RegProcedure (TestProcedure with 3 steps):
          TestVoidStep |> TestRegStep |> TestLastStep"""

    @test sprint(show, up) == "UnitProcedure"
    @test sprint(show, MIME("text/plain"), up) == """
        UnitProcedure (TestProcedure with 1 step):
          TestRegStep"""

    @test sprint(show, np) == "NullProcedure"
    @test sprint(show, MIME("text/plain"), np) == """
        NullProcedure (TestProcedure with 0 step)"""
end

@testset "SharedStatsStep" begin
    s1 = SharedStatsStep(TestRegStep(), 1)
    s2 = SharedStatsStep(TestRegStep(), [3,2])
    @test _sharedby(s1) == (1,)
    @test _sharedby(s2) == (2,3)
    @test _f(s1) == testregstep

    @test sprint(show, s1) == "TestRegStep"
    @test sprint(show, MIME("text/plain"), s1) ==
        "TestRegStep (StatsStep shared by 1 procedure)"
    @test sprint(show, s2) == "TestRegStep"
    @test sprint(show, MIME("text/plain"), s2) ==
        "TestRegStep (StatsStep shared by 2 procedures)"
end

@testset "PooledStatsProcedure" begin
    ps = (rp,)
    shared = ((SharedStatsStep(s, 1) for s in rp)...,)
    p1 = pool(rp)
    @test p1 == PooledStatsProcedure{typeof(ps), typeof(shared)}(ps, shared)
    @test length(p1) == 3
    @test eltype(PooledStatsProcedure) == SharedStatsStep
    @test firstindex(p1) == 1
    @test lastindex(p1) == 3
    @test p1[1] == SharedStatsStep(rp[1], 1)
    @test p1[1:3] == ((SharedStatsStep(s, 1) for s in rp)...,)
    @test iterate(p1) == (shared[1], 2)
    @test iterate(p1, 2) == (shared[2], 3)

    ps = (rp, rp)
    shared = ((SharedStatsStep(s, (1,2)) for s in rp)...,)
    p2 = pool(rp, rp)
    @test p2 == PooledStatsProcedure{typeof(ps), typeof(shared)}(ps, shared)
    @test length(p2) == 3

    ps = (up, up)
    shared = ((SharedStatsStep(s, (1,2)) for s in up)...,)
    p3 = pool(up, up)
    @test p3 == PooledStatsProcedure{typeof(ps), typeof(shared)}(ps, shared)
    @test length(p3) == 1

    ps = (np,)
    shared = ()
    p4 = pool(np)
    @test p4 == PooledStatsProcedure{typeof(ps), typeof(shared)}(ps, shared)
    @test length(p4) == 0

    ps = (up, rp)
    shared = (SharedStatsStep(rp[1], 2), SharedStatsStep(rp[2], (1,2)), SharedStatsStep(rp[3], 2))
    p5 = pool(up, rp)
    @test p5 == PooledStatsProcedure{typeof(ps), typeof(shared)}(ps, shared)
    @test length(p5) == 3

    ps = (rp, ip)
    shared = (SharedStatsStep(rp[1], 1), SharedStatsStep(ip[1], 2), SharedStatsStep(rp[2], 1),
        SharedStatsStep(ip[2], 2), SharedStatsStep(rp[3], (1,2)))
    p6 = pool(rp, ip)
    @test p6 == PooledStatsProcedure{typeof(ps), typeof(shared)}(ps, shared)
    @test length(p6) == 5

    @test sprint(show, p1) == "PooledStatsProcedure"
    @test sprint(show, MIME("text/plain"), p1) == """
        PooledStatsProcedure with 3 steps from 1 procedure:
          RegProcedure"""

    @test sprint(show, p2) == "PooledStatsProcedure"
    @test sprint(show, MIME("text/plain"), p2) == """
        PooledStatsProcedure with 3 steps from 2 procedures:
          RegProcedure
          RegProcedure"""

    @test sprint(show, MIME("text/plain"), p3) == """
        PooledStatsProcedure with 1 step from 2 procedures:
          UnitProcedure
          UnitProcedure"""

    @test sprint(show, MIME("text/plain"), p4) == """
        PooledStatsProcedure with 0 step from 1 procedure:
          NullProcedure"""
end

@testset "StatsSpec" begin
    s1 = StatsSpec("name", RP, (a="a",b="b"))
    s2 = StatsSpec("", RP, (a="a",b="b"))
    s3 = StatsSpec("", UP, (a="a",b="b"))
    s4 = StatsSpec("name", RP, (b="b", a="a"))
    s5 = StatsSpec("name", RP, (b="b", a="a", d="d"))
    @test s1 == s2
    @test s2 != s3
    @test s2 != s4
    @test s2 ≊ s4

    @test s1() == "aab"
    @test s3() == "ab"
    
    @test s1(keep=:a) == (a="a", result="aab")
    @test s1(keep=(:a,:c)) == (a="a", c="ab", result="aab")
    @test_throws ArgumentError s1(keep=1)
    @test s1(keepall=true) == (a="a", b="b", c="ab", result="aab")

    s6 = StatsSpec("", NP, NamedTuple())
    @test s6() === nothing

    @test sprint(show, s1) == "name"
    @test sprint(show, s2) == "unnamed"
    @test sprint(show, MIME("text/plain"), s1) == "name (StatsSpec for RegProcedure)"
    @test sprint(show, MIME("text/plain"), s2) == "unnamed (StatsSpec for RegProcedure)"

    @test _show_args(stdout, s1) === nothing
end

function testparser(args...; kwargs...)
    pargs = Pair{Symbol,Any}[kwargs...]
    for arg in args
        if arg isa Type{<:AbstractStatsProcedure}
            push!(pargs, :p=>arg)
        end
    end
    return (; pargs...)
end

testformatter(nt::NamedTuple) = (haskey(nt, :name) ? nt.name : "", nt.p, (a=nt.a, b=nt.b))

@testset "proceed" begin
    s1 = StatsSpec("s1", RP, (a="a",b="b"))
    s2 = StatsSpec("s2", RP, NamedTuple())
    s3 = StatsSpec("s3", RP, (a="a",b="b1"))
    s4 = StatsSpec("s4", UP, (a="a",b="b"))
    s5 = StatsSpec("s5", IP, (a="a",b="b"))

    @test proceed([s1]) == ["aab"]
    @test proceed([s1,s2], verbose=true) == ["aab", "aab"]
    @test proceed([s1,s3], verbose=true) == ["aab", "aab1"]
    @test proceed([s1,s4], verbose=true) == ["aab", "ab"]
    @test proceed([s1,s5], verbose=true) == ["aab", "aab"]
    @test proceed([s1,s4,s5], verbose=true) == ["aab", "ab", "aab"]
    @test_throws ArgumentError proceed(StatsSpec[])

    @test proceed([s1], keep=:a) == [(a="a",result="aab")]
    @test proceed([s1], keep=[:a,:b]) == [(a="a", b="b", result="aab")]
    @test proceed([s1], keep=(:d,)) == [(result="aab",)]
    @test proceed([s1], keepall=true) == [(a="a", b="b", c="ab", result="aab")]

    @test proceed([s2]) == ["aab"]
    @test proceed([s2], keep=:a) == [(result="aab",)]
    @test proceed([s2], keepall=true) == [(c="ab", result="aab",)]

    @test proceed([s1,s4], keep=[:a, :result]) ==
            [(a="a", result="aab"), (a="a",)]
    @test proceed([s1,s4], keepall=true) ==
        [(a="a", b="b", c="ab", result="aab"), (a="a", b="b", c="ab")]
end

@testset "@specset" begin
    r = @specset a="a0" begin
        StatsSpec(testformatter(testparser(RP; a="a1", b="b"))...)(;) end
    @test r == StatsSpec[StatsSpec("", RP, (a="a1", b="b"))]
    @test proceed(r) == ["a1a1b"]
    
    r = @specset a="a0" begin
        StatsSpec(testformatter(testparser(RP; b="b"))...)(;) end
    @test r == StatsSpec[StatsSpec("", RP, (a="a0", b="b"))]
    @test proceed(r) == ["a0a0b"]

    r = @specset a="a0" b="b0" begin
        StatsSpec(testformatter(testparser(RP))...)(;)
        StatsSpec(testformatter(testparser(RP; a="a1", b="b1"))...)(;)
    end
    @test r == StatsSpec[StatsSpec("", RP, (a="a0", b="b0")), StatsSpec("", RP, (a="a1", b="b1"))]
    @test proceed(r) == ["a0a0b0", "a1a1b1"]

    r = @specset a="a0" b="b0" begin
        StatsSpec(testformatter(testparser(RP))...)(;)
        StatsSpec(testformatter(testparser(RP; a="a1", c="c"))...)(;)
    end
    @test r == StatsSpec[StatsSpec("", RP, (a="a0", b="b0")), StatsSpec("", RP, (a="a1", b="b0"))]
    @test proceed(r) == ["a0a0b0", "a1a1b0"]

    a = "a0"
    r = @specset a=a begin
        StatsSpec(testformatter(testparser(RP; b="b"))...)(;) end
    @test proceed(r) == ["a0a0b"]
    
    r0 = @specset for i in 1:3
        a = "a"*string(i)
        StatsSpec(testformatter(testparser(RP; a=a, b="b"))...)(;)
        StatsSpec(testformatter(testparser(RP; a=a, b="b1"))...)(;)
    end
    @test proceed(r0) == ["a1a1b", "a1a1b1", "a2a2b", "a2a2b1", "a3a3b", "a3a3b1"]

    r1 = @specset begin
        i = 1
        a = "a"*string(i)
        StatsSpec(testformatter(testparser(RP; a=a, b="b"))...)(;)
        StatsSpec(testformatter(testparser(RP; a=a, b="b1"))...)(;)
        for i in 2:3
            a = "a"*string(i)
            StatsSpec(testformatter(testparser(RP; a=a, b="b"))...)(;)
            StatsSpec(testformatter(testparser(RP; a=a, b="b1"))...)(;)
        end
    end
    @test r1 == r0
end
