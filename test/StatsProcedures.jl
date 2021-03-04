using DiffinDiffsBase: _f, _get, groupargs,
    _sharedby, _show_args, _args_kwargs, _parse!, pool, proceed
import DiffinDiffsBase: required, default, transformed, combinedargs, copyargs

testvoidstep(a::String) = NamedTuple()
const TestVoidStep = StatsStep{:TestVoidStep, typeof(testvoidstep), true}
required(::TestVoidStep) = (:a,)

testregstep(a::String, b::String) = (c=a*b,)
const TestRegStep = StatsStep{:TestRegStep, typeof(testregstep), true}
default(::TestRegStep) = (a="a", b="b")

testlaststep(a::String, c::String) = (result=a*c,)
const TestLastStep = StatsStep{:TestLastStep, typeof(testlaststep), true}
default(::TestLastStep) = (a="a",)
transformed(::TestLastStep, ntargs::NamedTuple) = (ntargs.c,)

testcombinestep(a::String, bs::String...) = (c=collect(bs),)
const TestCombineStep = StatsStep{:TestCombineStep, typeof(testcombinestep), true}
default(::TestCombineStep) = (a="a",)
combinedargs(::TestCombineStep, ntargs) = [nt.b for nt in ntargs]

testarraystep(a::String, c::Array) = (result=c,)
const TestArrayStep = StatsStep{:TestArrayStep, typeof(testarraystep), true}
required(::TestArrayStep) = (:a, :c)
copyargs(::TestArrayStep) = (2,)

const TestUnnamedStep = StatsStep{:TestUnnamedStep, typeof(testregstep), true}

@testset "StatsStep" begin
    @testset "_get" begin
        @test _get(NamedTuple(), ()) == ()
        @test _get((a=1, b=2), (:a,)) == (1,)
        @test_throws ErrorException _get((b=2,), (:a,))

        @test _get(NamedTuple(), NamedTuple()) == ()
        @test _get((a=1,), (b=2,)) == (2,)
        @test _get((a=1,), (a=2, b=2)) == (1, 2)
        @test _get((a=1, b=2), (a=2,)) == (1,)
    end

    @testset "args" begin
        @test groupargs(TestVoidStep(), (a="a",)) == ("a",)
        @test_throws ErrorException groupargs(TestVoidStep(), (b="b",))

        @test groupargs(TestRegStep(), NamedTuple()) == ("a", "b")
        @test groupargs(TestRegStep(), (a="a1",)) == ("a1", "b")
        @test groupargs(TestRegStep(), (c="c",)) == ("a", "b")

        @test groupargs(TestUnnamedStep(), (a="a", b="b")) == ()
        @test combinedargs(TestRegStep(), (a="a",)) == ()
    end

    @testset "teststeps" begin
        @test _f(TestVoidStep()) == testvoidstep
        @test TestVoidStep()((a="a", b="b")) == (a="a", b="b")

        @test TestRegStep()() == (c="ab",)
        @test TestRegStep()((a="c", b="d")) == (a="c", b="d", c="cd")

        @test TestLastStep()((a="a", b="a", c="ab")) ==
            (a="a", b="a", c="ab", result="aab")
        
        @test TestCombineStep()((a="a", b="b")) == (a="a", b="b", c=["b"])
        c = ["c"]
        ret = TestArrayStep()((a="a", c=c,))
        @test ret.result === c

        @test sprint(show, TestVoidStep()) == "TestVoidStep"
        @test sprint(show, MIME("text/plain"), TestVoidStep()) ==
            "TestVoidStep (StatsStep that calls testvoidstep)"
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
const CP = TestProcedure{:CombineProcedure,Tuple{TestCombineStep,TestArrayStep}}
const cp = CP()
const AP = TestProcedure{:ArrayProcedure,Tuple{TestArrayStep}}
const ap = AP()

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
    @test _sharedby(s1) == [1]
    @test _sharedby(s2) == [2,3]
    @test _f(s1) == testregstep
    @test groupargs(s1, NamedTuple()) == ("a", "b")

    @test sprint(show, s1) == "TestRegStep"
    @test sprint(show, MIME("text/plain"), s1) ==
        "TestRegStep (StatsStep shared by 1 procedure)"
    @test sprint(show, s2) == "TestRegStep"
    @test sprint(show, MIME("text/plain"), s2) ==
        "TestRegStep (StatsStep shared by 2 procedures)"
end

@testset "PooledStatsProcedure" begin
    ps = (rp,)
    shared = [SharedStatsStep(s, 1) for s in rp]
    p1 = pool(rp)
    @test p1 == PooledStatsProcedure(ps, shared)
    @test length(p1) == 3
    @test eltype(PooledStatsProcedure) == SharedStatsStep
    @test firstindex(p1) == 1
    @test lastindex(p1) == 3
    @test p1[1] == SharedStatsStep(rp[1], 1)
    @test p1[1:3] == [SharedStatsStep(s, 1) for s in rp]
    @test iterate(p1) == (shared[1], 2)
    @test iterate(p1, 2) == (shared[2], 3)

    ps = (rp, rp)
    shared = [SharedStatsStep(s, (1,2)) for s in rp]
    p2 = pool(rp, rp)
    @test p2 == PooledStatsProcedure(ps, shared)
    @test length(p2) == 3

    ps = (up, up)
    shared = [SharedStatsStep(s, (1,2)) for s in up]
    p3 = pool(up, up)
    @test p3 == PooledStatsProcedure(ps, shared)
    @test length(p3) == 1

    ps = (np,)
    shared = []
    p4 = pool(np)
    @test p4 == PooledStatsProcedure(ps, shared)
    @test length(p4) == 0

    ps = (up, rp)
    shared = [SharedStatsStep(rp[1], 2), SharedStatsStep(rp[2], (1,2)), SharedStatsStep(rp[3], 2)]
    p5 = pool(up, rp)
    @test p5 == PooledStatsProcedure(ps, shared)
    @test length(p5) == 3

    ps = (rp, ip)
    shared = [SharedStatsStep(rp[1], 1), SharedStatsStep(ip[1], 2), SharedStatsStep(rp[2], 1),
        SharedStatsStep(ip[2], 2), SharedStatsStep(rp[3], (1,2))]
    p6 = pool(rp, ip)
    @test p6 == PooledStatsProcedure(ps, shared)
    @test length(p6) == 5

    ps = (rp, cp)
    shared = [SharedStatsStep(rp[1], 1), SharedStatsStep(rp[2], 1),
        SharedStatsStep(rp[3], 1), SharedStatsStep(cp[1], 2), SharedStatsStep(cp[2], 2)]
    p7 = pool(rp, cp)
    @test p7 == PooledStatsProcedure(ps, shared)
    @test length(p7) == 5

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
    s1 = StatsSpec("name", RP, (a="a", b="b"))
    s2 = StatsSpec("", RP, (a="a", b="b"))
    s3 = StatsSpec("", UP, (a="a", b="b"))
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
    @test s6(keepall=true) == NamedTuple()
    @test s6(keep=:result) == NamedTuple()

    @test sprint(show, s1) == "name"
    @test sprint(show, s2) == "unnamed"
    @test sprint(show, MIME("text/plain"), s1) == "name (StatsSpec for RegProcedure)"
    @test sprint(show, MIME("text/plain"), s2) == "unnamed (StatsSpec for RegProcedure)"

    @test _show_args(stdout, s1) === nothing
end

function testparser(args, kwargs)
    kwargs = Dict{Symbol,Any}(kwargs...)
    for arg in args
        if arg isa Type{<:AbstractStatsProcedure}
            kwargs[:p] = arg
        end
    end
    return kwargs
end

testformatter(arg::Dict{Symbol,Any}) = (get(arg, :name, ""), arg[:p], (a=arg[:a], b=arg[:b]))

@testset "proceed" begin
    s1 = StatsSpec("s1", RP, (a="a", b="b"))
    s2 = StatsSpec("s2", RP, (a="a",))
    s3 = StatsSpec("s3", RP, (a="a", b="b1"))
    s4 = StatsSpec("s4", UP, (a="a", b="b"))
    s5 = StatsSpec("s5", IP, (a="a", b="b"))
    s6 = StatsSpec("s6", CP, (a="a", b="b1"))
    s7 = StatsSpec("s7", CP, (a="a", b="b2"))
    c = ["c"]
    s8 = StatsSpec("s8", AP, (a="a", c=c))
    s9 = StatsSpec("s9", AP, (a="a1", c=c))
    s10 = StatsSpec("s10", NP, NamedTuple())
    
    @test proceed([s1]) == ["aab"]
    @test proceed([s1,s2], verbose=true) == ["aab", "aab"]
    @test proceed([s1,s3], verbose=true) == ["aab", "aab1"]
    @test proceed([s1,s4], verbose=true) == ["aab", "ab"]
    @test proceed([s1,s5], verbose=true) == ["aab", "aab"]
    @test proceed([s1,s4,s5], verbose=true) == ["aab", "ab", "aab"]

    @test proceed([s1], keep=:a) == [(a="a",result="aab")]
    @test proceed([s1], keep=[:a,:b]) == [(a="a", b="b", result="aab")]
    @test proceed([s1], keep=(:d,)) == [(result="aab",)]
    @test proceed([s1], keepall=true) == [(a="a", b="b", c="ab", result="aab")]

    @test proceed([s2]) == ["aab"]
    @test proceed([s2], keep=:b) == [(result="aab",)]
    @test proceed([s2], keepall=true) == [(a="a", c="ab", result="aab",)]

    @test proceed([s1,s4], keep=[:a, :result]) ==
            [(a="a", result="aab"), (a="a",)]
    @test proceed([s1,s4], keepall=true) ==
        [(a="a", b="b", c="ab", result="aab"), (a="a", b="b", c="ab")]

    @test proceed([s6], keepall=true) == [(a="a", b="b1", c=["b1"], result=["b1"])]
    ret = proceed([s6,s7], keepall=true)
    @test ret == [(a="a", b="b1", c=["b1", "b2"], result=["b1", "b2"]),
        (a="a", b="b2", c=["b1", "b2"], result=["b1", "b2"])]
    @test ret[1].c === ret[2].c
    @test ret[1].result === ret[2].result

    ret = proceed([s8], keepall=true)
    @test ret[1].c === ret[1].result
    ret = proceed([s8,s9], keepall=true)
    @test ret[1].c !== ret[1].result

    @test proceed([s10]) == [nothing]
    @test proceed([s10], keepall=true) == NamedTuple[NamedTuple()]
    @test proceed([s10], keep=:result) == NamedTuple[NamedTuple()]

    @test proceed([s1], pause=1) == ["b"]

    @test_throws ArgumentError proceed(StatsSpec[])
end

@testset "_parse!" begin
    options = :(Dict{Symbol, Any}())
    _parse!(options, [:a, :(b=1)])
    @test eval(options) == Dict{Symbol, Any}(:a => true, :b => 1)
    @test _parse!(options, [:noproceed, :(b=1)]) == true
    @test _parse!(options, [:(noproceed=false), :(b=1)]) == false
    @test_throws ArgumentError _parse!(options, [1])
end

@testset "@specset" begin
    s = @specset [noproceed=true] a="a0" begin
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:a=>"a1", :b=>"b")))...)(;) end
    @test s == StatsSpec[StatsSpec("", RP, (a="a1", b="b"))]
    @test proceed(s) == ["a1a1b"]
    
    s = @specset [noproceed] a="a0" begin
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:b=>"b")))...)(;) end
    @test s == StatsSpec[StatsSpec("", RP, (a="a0", b="b"))]
    @test proceed(s) == ["a0a0b"]

    s = @specset [noproceed] a="a0" b="b0" begin
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}()))...)
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:a=>"a1", :b=>"b1")))...)(;)
    end
    @test s == StatsSpec[StatsSpec("", RP, (a="a0", b="b0")), StatsSpec("", RP, (a="a1", b="b1"))]
    @test proceed(s) == ["a0a0b0", "a1a1b1"]

    s = @specset [noproceed] a="a0" b="b0" begin
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}()))...)(;)
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:a=>"a1", :c=>"c")))...)
    end
    @test s == StatsSpec[StatsSpec("", RP, (a="a0", b="b0")), StatsSpec("", RP, (a="a1", b="b0"))]
    @test proceed(s) == ["a0a0b0", "a1a1b0"]

    a = "a0"
    r = @specset [verbose keepall] a=a begin
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:b=>"b")))...) end
    @test r == [(a="a0", b="b", c="a0b", result="a0a0b")]

    r = @specset [verbose keep=:a] a=a begin
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:b=>"b")))...) end
    @test r == [(a="a0", result="a0a0b")]

    r = @specset [verbose keep=[:a]] a=a begin
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:b=>"b")))...) end
    @test r == [(a="a0", result="a0a0b")]

    r = @specset [verbose pause=1] a=a begin
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:b=>"b")))...) end
    @test r == ["b"]
    
    s0 = @specset [noproceed] for i in 1:3
        a = "a"*string(i)
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:a=>a, :b=>"b")))...)(;)
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:a=>a, :b=>"b1")))...)(;)
    end
    @test proceed(s0) == ["a1a1b", "a1a1b1", "a2a2b", "a2a2b1", "a3a3b", "a3a3b1"]

    s1 = @specset [noproceed] begin
        i = 1
        a = "a"*string(i)
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:a=>a, :b=>"b")))...)(;)
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:a=>a, :b=>"b1")))...)(;)
        for i in 2:3
            a = "a"*string(i)
            StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:a=>a, :b=>"b")))...)(;)
            StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:a=>a, :b=>"b1")))...)(;)
        end
    end
    @test s1 == s0

    r = @specset for i in 1:3
        a = "a"*string(i)
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:a=>a, :b=>"b")))...)(;)
        StatsSpec(testformatter(testparser(Any[RP], Dict{Symbol,Any}(:a=>a, :b=>"b1")))...)(;)
    end
    @test r == ["a1a1b", "a1a1b1", "a2a2b", "a2a2b1", "a3a3b", "a3a3b1"]

    r = @specset RP a="a1" begin
        StatsSpec(testformatter(testparser(Any[], Dict{Symbol,Any}(:b=>"b")))...)(;)
        for i in 2:3
            StatsSpec(testformatter(testparser(Any[], Dict{Symbol,Any}(:a=>"a"*"$i", :b=>"b")))...)(;)
        end
    end
    @test r == ["a1a1b", "a2a2b", "a3a3b"]
end
