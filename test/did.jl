using DiffinDiffsBase: parse_didargs
import DiffinDiffsBase: valid_didargs

const testterm = treat(:g, TR, PR)

function valid_didargs(d::Type{TestDID}, ::AbstractTreatment, ::AbstractParallel,
        ntargs::NamedTuple)
    name = haskey(ntargs, :name) ? ntargs.name : ""
    ntargs = NamedTuple{(setdiff([keys(ntargs)...], [:name, :d])...,)}(ntargs)
    return d, name, ntargs
end

@testset "DiffinDiffsEstimator" begin
    d = DefaultDID()
    @test length(d) == 0
    @test eltype(d) == StatsStep
    @test_throws BoundsError d[1]
    @test collect(d) == StatsStep[]
    @test iterate(d) === nothing

    d = TestDID()
    @test length(d) == 2
    @test eltype(d) == StatsStep
    @test d[1] == TestStep()
    @test d[1:2] == [TestStep(), TestResult()]
    @test d[[2,1]] == [TestResult(), TestStep()]
    @test_throws BoundsError d[3]
    @test_throws MethodError d[:a]
    @test collect(d) == StatsStep[TestStep(), TestResult()]
    @test iterate(d) == (TestStep(), 2)
    @test iterate(d, 2) === (TestResult(), 3)
    @test iterate(d, 3) === nothing
end

@testset "parse_didargs" begin
    @test parse_didargs() == NamedTuple()
    @test parse_didargs("test") == (name="test",)

    ntargs = parse_didargs(TestDID, TR, PR, a=1, b=2)
    @test ntargs ≊ (d=TestDID, tr=TR, pr=PR, a=1, b=2)

    ntargs = parse_didargs("test", testterm, TestDID)
    @test ntargs ≊ (d=TestDID, tr=TR, pr=PR, name="test", treatname=:g)

    ntargs0 = parse_didargs(TestDID, term(:y) ~ testterm, "test")
    @test ntargs0 ≊ (d=TestDID, tr=TR, pr=PR, name="test", yterm=term(:y), treatname=:g)

    ntargs1 = parse_didargs(TestDID, "test", @formula(y ~ treat(g, ttreat(t, 0), tpara(0))))
    @test ntargs1 ≊ ntargs0

    ntargs0 = parse_didargs(TestDID, term(:y) ~ testterm & term(:z) + term(:x))
    @test ntargs0 ≊ (d=TestDID, tr=TR, pr=PR, yterm=term(:y), treatname=:g, treatintterms=(term(:z),), xterms=(term(:x),))
    
    ntargs1 = parse_didargs(TestDID,
        @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x))
    @test ntargs1 ≊ ntargs0

    @test_throws ArgumentError parse_didargs('a', :a, 1)
    @test_throws ArgumentError parse_didargs(TestDID, DefaultDID)
    @test_throws ArgumentError parse_didargs(TR, PR, TR)
end

@testset "valid_didargs" begin
    @testset "DefaultDID" begin
        @test_throws ErrorException did(TR, PR)
    end
end

@testset "StatsSpec" begin
    @testset "== ≊" begin
        sp1 = StatsSpec(DefaultDID, "", NamedTuple())
        sp2 = StatsSpec(DefaultDID, "name", NamedTuple())
        @test sp1 == sp2
        @test sp1 ≊ sp2

        sp1 = StatsSpec(DefaultDID, "", (tr=TR, pr=PR, a=1, b=2))
        sp2 = StatsSpec(DefaultDID, "", (pr=PR, tr=TR, b=2, a=1))
        @test sp1 != sp2
        @test sp1 ≊ sp2

        sp2 = StatsSpec(DefaultDID, "", (tr=TR, pr=PR, a=1.0, b=2.0))
        @test sp1 == sp2
        @test sp1 ≊ sp2

        sp2 = StatsSpec(DefaultDID, "", (tr=TR, pr=PR, a=1, b=2, c=3))
        @test !(sp1 ≊ sp2)

        sp2 = StatsSpec(DefaultDID, "", (tr=TR, pr=PR, a=1, b=1))
        @test !(sp1 ≊ sp2)
    end

    @testset "show" begin
        sp = StatsSpec(DefaultDID, "", NamedTuple())
        @test sprint(show, sp) == "StatsSpec{DefaultDID}"
        @test sprintcompact(sp) == "StatsSpec{DefaultDID}"

        sp = StatsSpec(DefaultDID, "name", NamedTuple())
        @test sprint(show, sp) == "StatsSpec{DefaultDID}: name"
        @test sprintcompact(sp) == "StatsSpec{DefaultDID}: name"
        
        sp = StatsSpec(TestDID, "", (tr=dynamic(:time,-1), pr=nevertreated(-1)))
        @test sprint(show, sp) == """
            StatsSpec{TestDID}:
              Dynamic{S}(-1)
              NeverTreated{U,P}([-1])"""
        @test sprintcompact(sp) == "StatsSpec{TestDID}"
        
        sp = StatsSpec(TestDID, "", (tr=dynamic(:time,-1),))
        @test sprint(show, sp) == """
            StatsSpec{TestDID}:
              Dynamic{S}(-1)"""
        @test sprintcompact(sp) == "StatsSpec{TestDID}"
        
        sp = StatsSpec(TestDID, "name", (pr=nevertreated(-1),))
        @test sprint(show, sp) == """
            StatsSpec{TestDID}: name
              NeverTreated{U,P}([-1])"""
        @test sprintcompact(sp) == "StatsSpec{TestDID}: name"
    end
end

@testset "didspec" begin
    @test_throws ArgumentError @didspec
    @test_throws ArgumentError didspec()

    sp0 = StatsSpec(TestDID, "", (tr=TR, pr=PR, a=1, b=2))
    sp1 = didspec(TestDID, TR, PR, a=1, b=2)
    @test sp1 ≊ sp0
    @test sp0 ≊ @didspec TR a=1 b=2 PR TestDID

    sp2 = StatsSpec(TestDID, "name", (tr=TR, pr=PR, a=1, b=2))
    sp3 = didspec("name", TR, PR, TestDID, b=2, a=1)
    @test sp2 ≊ sp1
    @test sp3 ≊ sp2
    @test sp3 ≊ @didspec TR PR TestDID "name" b=2 a=1

    sp4 = StatsSpec(TestDID, "name", (tr=TR, pr=PR, treatname=:g))
    sp5 = didspec(TestDID, testterm)
    @test sp5 ≊ sp4
    @test sp4 ≊ @didspec TestDID testterm "name"

    sp6 = StatsSpec(TestDID, "", (tr=TR, pr=PR, 
        yterm=term(:y), treatname=:g, treatintterms=(term(:z),), xterms=(term(:x),)))
    sp7 = didspec(TestDID, term(:y) ~ testterm & term(:z) + term(:x))
    sp8 = didspec(TestDID, @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x))
    @test sp7 ≊ sp6
    @test sp8 === sp7
    @test sp6 === @didspec TestDID term(:y) ~ testterm & term(:z) + term(:x)
    @test sp6 === @didspec TestDID @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x)
end

@testset "@did" begin
    d0 = @did TestDID TR PR
    d1 = @did PR TR TestDID
    @test d0 == "testresult"
    @test d1 == d0

    d = @did [keepall] TestDID testterm
    @test d ≊ (tr=TR, pr=PR, treatname=:g, str=sprint(show, TR), spr=sprint(show, PR), result="testresult") 
    d0 = @did [keepall] TestDID term(:y) ~ testterm
    @test d0 ≊ merge(d, (yterm=term(:y),))
    d1 = @did [keepall] TestDID @formula(y ~ treat(g, ttreat(t, 0), tpara(0))) "test"
    @test d1 ≊ d0
    d0 = @did [keepall] TestDID term(:y) ~ testterm & term(:z) + term(:x)
    @test d0 ≊ merge(d, (yterm=term(:y), treatintterms=(term(:z),), xterms=(term(:x),)))
    d1 = @did [keepall] "test" TestDID @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x)
    @test d1 ≊ d0

    d = @did [keep=:treatname] TestDID testterm
    @test d ≊ (treatname=:g, result="testresult")
    d = @did [keep=[:treatname,:tr]] TestDID testterm
    @test d ≊ (treatname=:g, tr=TR, result="testresult")

    @test_throws ArgumentError @did TestDID
    @test_throws ArgumentError @did TestDID TR
    @test_throws ArgumentError @did TestDID TR PR PR
    @test_throws ArgumentError @did TestDID TR PR 1
    @test_throws ErrorException @did NotImplemented TR PR

    @test_throws ArgumentError @did [keep] TestDID testterm
    @test_throws ArgumentError @did [keep=1] TestDID testterm
    @test_throws ArgumentError @did [keep="treatname"] TestDID testterm
end
