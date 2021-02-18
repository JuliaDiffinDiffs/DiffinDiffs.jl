const testterm = treat(:g, TR, PR)

function valid_didargs(d::Type{TestDID}, ::AbstractTreatment, ::AbstractParallel,
        ntargs::NamedTuple)
    name = haskey(ntargs, :name) ? ntargs.name : ""
    ntargs = NamedTuple{(setdiff([keys(ntargs)...], [:name, :d])...,)}(ntargs)
    return name, d, ntargs
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
    @test d[1:2] == [TestStep(), TestNextStep()]
    @test d[[2,1]] == [TestNextStep(), TestStep()]
    @test_throws BoundsError d[3]
    @test_throws MethodError d[:a]
    @test collect(d) == StatsStep[TestStep(), TestNextStep()]
    @test iterate(d) == (TestStep(), 2)
    @test iterate(d, 2) === (TestNextStep(), 3)
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
    nt = (d=TestDID, tr=TR, pr=PR)
    @test valid_didargs(nt) == ("", TestDID, (tr=TR, pr=PR))
    nt = (d=TestDID, tr=TR, pr=PR, name="name")
    @test valid_didargs(nt) == ("name", TestDID, (tr=TR, pr=PR))
    nt = (d=TestDID, tr=TR, a=1)
    @test_throws ArgumentError valid_didargs(nt)
    nt = (tr=TR, pr=PR)
    @test_throws ErrorException valid_didargs(nt)
    nt = (d=NotImplemented, tr=TR, pr=PR)
    @test_throws ErrorException valid_didargs(nt)
end

@testset "StatsSpec" begin
    @testset "== ≊" begin
        sp1 = StatsSpec("", DefaultDID, NamedTuple())
        sp2 = StatsSpec("", DefaultDID, NamedTuple())
        @test sp1 == sp2
        @test sp1 ≊ sp2

        sp1 = StatsSpec("", DefaultDID, (tr=TR, pr=PR, a=1, b=2))
        sp2 = StatsSpec("", DefaultDID, (pr=PR, tr=TR, b=2, a=1))
        @test sp1 != sp2
        @test sp1 ≊ sp2

        sp2 = StatsSpec("", DefaultDID, (tr=TR, pr=PR, a=1.0, b=2.0))
        @test sp1 == sp2
        @test sp1 ≊ sp2

        sp2 = StatsSpec("", DefaultDID, (tr=TR, pr=PR, a=1, b=2, c=3))
        @test !(sp1 ≊ sp2)

        sp2 = StatsSpec("", DefaultDID, (tr=TR, pr=PR, a=1, b=1))
        @test !(sp1 ≊ sp2)
    end

    @testset "show" begin
        sp = StatsSpec("", DefaultDID, NamedTuple())
        @test sprint(show, sp) == "unnamed"
        @test sprint(show, MIME("text/plain"), sp) == "unnamed (StatsSpec for DefaultDID)"

        sp = StatsSpec("name", DefaultDID, NamedTuple())
        @test sprint(show, sp) == "name"
        @test sprint(show, MIME("text/plain"), sp) == "name (StatsSpec for DefaultDID)"

        sp = StatsSpec("", TestDID, (tr=dynamic(:time,-1), pr=nevertreated(-1)))
        @test sprint(show, sp) == "unnamed"
        @test sprint(show, MIME("text/plain"), sp) == """
            unnamed (StatsSpec for TestDID):
              Dynamic{S}([-1])
              NeverTreated{U,P}([-1])"""

        sp = StatsSpec("", TestDID, (tr=dynamic(:time,-1),))
        @test sprint(show, sp) == "unnamed"
        @test sprint(show, MIME("text/plain"), sp) == """
            unnamed (StatsSpec for TestDID):
              Dynamic{S}([-1])"""
        
        sp = StatsSpec("name", TestDID, (pr=nevertreated(-1),))
        @test sprint(show, sp) == "name"
        @test sprint(show, MIME("text/plain"), sp) == """
            name (StatsSpec for TestDID):
              NeverTreated{U,P}([-1])"""
    end
end

@testset "didspec @did" begin
    @test_throws ArgumentError @did [noproceed]
    @test_throws ArgumentError didspec()

    sp0 = StatsSpec("", TestDID, (tr=TR, pr=PR, a=1, b=2))
    sp1 = didspec(TestDID, TR, PR, a=1, b=2)
    @test sp1 ≊ sp0
    @test sp0 ≊ @did [noproceed] TR a=1 b=2 PR TestDID

    sp2 = StatsSpec("name", TestDID, (tr=TR, pr=PR, a=1, b=2))
    sp3 = didspec("name", TR, PR, TestDID, b=2, a=1)
    @test sp2 ≊ sp1
    @test sp3 ≊ sp2
    @test sp3 ≊ @did [noproceed] TR PR TestDID "name" b=2 a=1

    sp4 = StatsSpec("name", TestDID, (tr=TR, pr=PR, treatname=:g))
    sp5 = didspec(TestDID, testterm)
    @test sp5 ≊ sp4
    @test sp4 ≊ @did [noproceed] TestDID testterm "name"

    sp6 = StatsSpec("", TestDID, (tr=TR, pr=PR, 
        yterm=term(:y), treatname=:g, treatintterms=(term(:z),), xterms=(term(:x),)))
    sp7 = didspec(TestDID, term(:y) ~ testterm & term(:z) + term(:x))
    sp8 = didspec(TestDID, @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x))
    @test sp7 ≊ sp6
    @test sp8 === sp7
    @test sp6 === @did [noproceed] TestDID term(:y) ~ testterm & term(:z) + term(:x)
    @test sp6 === @did [noproceed] TestDID @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x)
end

@testset "_treatnames" begin
    t = Table((rel=[1, 2],))
    @test _treatnames(t) == ["rel: 1", "rel: 2"]
    r = TestResult(2, 2)
    @test _treatnames(r.treatinds) == ["rel: $a & c: $b" for a in 1:2 for b in 1:2]
end

@testset "DIDResult" begin
    r = TestResult(2, 2)

    @test coef(r) == r.coef
    @test coef(r, 1) == 1
    @test coef(r, "rel: 1 & c: 1") == 1
    @test coef(r, :c5) == 5
    @test coef(r, 1:2) == [1.0, 2.0]
    @test coef(r, 5:-1:3) == [5.0, 4.0, 3.0]
    @test coef(r, (1, :c5, "rel: 1 & c: 1")) == [1.0, 5.0, 1.0]
    @test coef(r, [1 "rel: 1 & c: 1" :c5]) == [1.0 1.0 5.0]
    @test coef(x->true, r) == collect(Float64, 1:4)
    @test coef(x->x.rel==1, r) == [1.0, 2.0]

    @test vcov(r) == r.vcov
    @test vcov(r, 1) == 1
    @test vcov(r, 1, 2) == 2
    @test vcov(r, "rel: 1 & c: 1") == 1
    @test vcov(r, :c5) == 25
    @test vcov(r, "rel: 1 & c: 1", :c5) == 5
    @test vcov(r, 1:2) == r.vcov[1:2, 1:2]
    @test vcov(r, 5:-1:3) == r.vcov[5:-1:3, 5:-1:3]
    @test vcov(r, (1, :c5, "rel: 1 & c: 1")) == r.vcov[[1,5,1], [1,5,1]]
    @test vcov(r, [1 :c5 "rel: 1 & c: 1"]) == r.vcov[[1,5,1], [1,5,1]]
    @test vcov(x->true, r) == r.vcov[1:4, 1:4]
    @test vcov(x->x.rel==1, r) == r.vcov[1:2, 1:2]

    @test nobs(r) == 6
    @test dof_residual(r) == 5
    @test responsename(r) == "y"
    @test outcomename(r) == responsename(r)
    @test coefnames(r) == r.coefnames
    @test treatnames(r) == r.coefnames[1:4]
    @test weights(r) == :w
end

@testset "did @did" begin
    r = result(TestDID, NamedTuple()).result
    d0 = @did TestDID TR PR
    d1 = @did PR TR TestDID
    @test d0 == r
    @test d1 == d0
    @test did(TestDID, TR, PR) == r
    @test did(PR, TR, TestDID) == r

    d = @did [keepall] TestDID testterm
    @test d ≊ (tr=TR, pr=PR, treatname=:g, str=sprint(show, TR), spr=sprint(show, PR),
        next="next"*sprint(show, TR), result=r)
    @test did(TestDID, testterm; keepall=true) == d

    d0 = @did [keepall] TestDID term(:y) ~ testterm
    @test d0 ≊ merge(d, (yterm=term(:y),))
    @test did(TestDID, term(:y) ~ testterm; keepall=true) == d0
    d1 = @did [keepall] TestDID @formula(y ~ treat(g, ttreat(t, 0), tpara(0))) "test"
    @test d1 ≊ d0
    @test did(TestDID, @formula(y ~ treat(g, ttreat(t, 0), tpara(0))); keepall=true) == d1

    d0 = @did [keepall] TestDID term(:y) ~ testterm & term(:z) + term(:x)
    @test d0 ≊ merge(d, (yterm=term(:y), treatintterms=(term(:z),), xterms=(term(:x),)))
    @test did(TestDID, term(:y) ~ testterm & term(:z) + term(:x); keepall=true) == d0
    d1 = @did [keepall] "test" TestDID @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x)
    @test d1 ≊ d0
    @test did(TestDID, @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x); keepall=true) == d1

    d = @did [keep=:treatname] TestDID testterm
    @test d ≊ (treatname=:g, result=r)
    @test did(TestDID, testterm; keep=:treatname) == d
    d = @did [keep=[:treatname,:tr]] TestDID testterm
    @test d ≊ (treatname=:g, tr=TR, result=r)
    @test did(TestDID, testterm; keep=[:treatname,:tr]) == d

    @test_throws ArgumentError @did TestDID
    @test_throws ArgumentError did(TestDID)
    @test_throws ArgumentError @did TestDID TR
    @test_throws ArgumentError did(TestDID, TR)
    @test_throws ArgumentError @did TestDID TR PR PR
    @test_throws ArgumentError did(TestDID, TR, PR, PR)
    @test_throws ArgumentError @did TestDID TR PR 1
    @test_throws ArgumentError did(TestDID, TR, PR, 1)
    @test_throws ErrorException @did NotImplemented TR PR
    @test_throws ErrorException did(NotImplemented, TR, PR)

    @test_throws ArgumentError @did [keep] TestDID testterm
    @test_throws ArgumentError did(TestDID, testterm, keep=true)
    @test_throws ArgumentError @did [keep=1] TestDID testterm
    @test_throws ArgumentError did(TestDID, testterm, keep=1)
    @test_throws ArgumentError @did [keep="treatname"] TestDID testterm
    @test_throws ArgumentError did(TestDID, testterm, keep="treatname")
end

@testset "@specset @did" begin
    s = @specset [noproceed] begin
        @did TestDID TR PR
    end
    @test s == [didspec(TestDID, TR, PR)]
    @test proceed(s) == [@did TestDID TR PR]

    s = @specset [noproceed] begin
        @did TestDID TR PR
        @did PR TR TestDID
    end
    @test s == StatsSpec[didspec(TestDID, TR, PR), didspec(PR, TR, TestDID)]

    s = @specset [noproceed] DefaultDID PR a=1 begin
        @did TR PR TestDID a=2
        @did TR TestDID
    end
    @test s[1] ≊ didspec(TestDID, TR, PR; a=2)
    @test s[2] ≊ didspec(TestDID, TR, PR; a=1)

    s = @specset [noproceed] DefaultDID PR begin
        @did [keep=:treatname verbose] TestDID testterm
        @did [noproceed] TestDID @formula(y ~ treat(g, ttreat(t, 0), tpara(0)))
    end
    @test s[1] ≊ didspec(TestDID, TR, PR; treatname=:g)
    @test s[2] ≊ didspec(TestDID, TR, PR; yterm=term(:y), treatname=:g)

    s = @specset [noproceed] for i in 1:2
        @did "name"*"$i" TestDID TR PR a=i
    end
    @test s[1] ≊ didspec("name1", TestDID, TR, PR; a=1)
    @test s[2] ≊ didspec("name2", TestDID, TR, PR; a=2)

    s = @specset [noproceed] DefaultDID PR a=1 begin
        @did "name" TR PR TestDID a=0
        for i in 1:2
            @did "name"*"$i" TR TestDID a=i
        end
    end
    @test s[1] ≊ didspec("name", TestDID, TR, PR; a=0)
    @test s[2] ≊ didspec("name1", TestDID, TR, PR; a=1)
    @test s[3] ≊ didspec("name2", TestDID, TR, PR; a=2)
end
