const testterm = treat(:g, TR, PR)

function valid_didargs(d::Type{TestDID}, ::AbstractTreatment, ::AbstractParallel,
        args::Dict{Symbol,Any})
    name = get(args, :name, "")
    ns = (setdiff([keys(args)...], [:name, :d])...,)
    args = NamedTuple{ns}(map(n->args[n], ns))
    return name, d, args
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

@testset "parse_didargs!" begin
    args = Dict{Symbol,Any}(:xterms=>(term(:x),), :treatintterms=>:z)
    _totermset!(args, :xterms)
    @test args[:xterms] == TermSet(term(:x))
    _totermset!(args, :treatintterms)
    @test args[:treatintterms] == TermSet(term(:z))

    @test parse_didargs!(Any["test"], Dict{Symbol,Any}()) == Dict{Symbol,Any}(:name=>"test")

    args = parse_didargs!([TestDID, TR, PR], Dict{Symbol,Any}(:a=>1, :b=>2))
    @test args == Dict{Symbol,Any}(pairs((d=TestDID, tr=TR, pr=PR, a=1, b=2)))

    args = parse_didargs!(["test", testterm, TestDID], Dict{Symbol,Any}())
    @test args == Dict{Symbol,Any}(pairs((d=TestDID, tr=TR, pr=PR, name="test", treatname=:g)))

    args0 = parse_didargs!([TestDID, term(:y) ~ testterm, "test"], Dict{Symbol,Any}())
    @test args0 == Dict{Symbol,Any}(pairs((d=TestDID, tr=TR, pr=PR, name="test", yterm=term(:y), treatname=:g, treatintterms=TermSet(), xterms=TermSet())))

    args1 = parse_didargs!([TestDID, "test", @formula(y ~ treat(g, ttreat(t, 0), tpara(0)))],
        Dict{Symbol,Any}())
    @test args1 == args0

    args0 = parse_didargs!([TestDID, term(:y) ~ testterm & term(:z) + term(:x)],
        Dict{Symbol,Any}())
    @test args0 == Dict{Symbol,Any}(pairs((d=TestDID, tr=TR, pr=PR, yterm=term(:y),
        treatname=:g, treatintterms=TermSet(term(:z)), xterms=TermSet(term(:x)))))
    
    args1 = parse_didargs!([TestDID,
        @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x)], Dict{Symbol,Any}())
    @test args1 == args0

    @test_throws ArgumentError parse_didargs!(['a', :a, 1], Dict{Symbol,Any}())
    @test parse_didargs!(Any[TestDID, DefaultDID], Dict{Symbol,Any}()) == Dict{Symbol,Any}(:d=>DefaultDID)
end

@testset "valid_didargs" begin
    arg = Dict{Symbol,Any}(pairs((d=TestDID, tr=TR, pr=PR)))
    @test valid_didargs(arg) == ("", TestDID, (tr=TR, pr=PR))
    arg = Dict{Symbol,Any}(pairs((name="name", d=TestDID, tr=TR, pr=PR)))
    @test valid_didargs(arg) == ("name", TestDID, (tr=TR, pr=PR))
    arg = Dict{Symbol,Any}(pairs((d=TestDID, tr=TR, a=1)))
    @test_throws ArgumentError valid_didargs(arg)
    arg = Dict{Symbol,Any}(pairs((tr=TR, pr=PR)))
    @test_throws ErrorException valid_didargs(arg)
    arg = Dict{Symbol,Any}(pairs((d=NotImplemented, tr=TR, pr=PR)))
    @test_throws ErrorException valid_didargs(arg)
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
              Dynamic{S}(-1)
              NeverTreated{U,P}(-1)"""

        sp = StatsSpec("", TestDID, (tr=dynamic(:time,-1),))
        @test sprint(show, sp) == "unnamed"
        @test sprint(show, MIME("text/plain"), sp) == """
            unnamed (StatsSpec for TestDID):
              Dynamic{S}(-1)"""
        
        sp = StatsSpec("name", TestDID, (pr=notyettreated(-1),))
        @test sprint(show, sp) == "name"
        @test sprint(show, MIME("text/plain"), sp) == """
            name (StatsSpec for TestDID):
              NotYetTreated{U,P}(-1)"""
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

    sp6 = StatsSpec("", TestDID, (tr=TR, pr=PR, yterm=term(:y), treatname=:g,
        treatintterms=TermSet(term(:z)), xterms=TermSet(term(:x))))
    sp7 = didspec(TestDID, term(:y) ~ testterm & term(:z) + term(:x))
    sp8 = didspec(TestDID, @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x))
    @test sp7 ≊ sp6
    @test sp8 ≊ sp7
    @test sp6 ≊ @did [noproceed] TestDID term(:y) ~ testterm & term(:z) + term(:x)
    @test sp6 ≊ @did [noproceed] TestDID @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x)
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
    @test d0 ≊ merge(d, (yterm=term(:y), treatintterms=TermSet(), xterms=TermSet()))
    @test did(TestDID, term(:y) ~ testterm; keepall=true) == d0
    d1 = @did [keepall] TestDID @formula(y ~ treat(g, ttreat(t, 0), tpara(0))) "test"
    @test d1 ≊ d0
    @test did(TestDID, @formula(y ~ treat(g, ttreat(t, 0), tpara(0))); keepall=true) == d1

    d0 = @did [keepall] TestDID term(:y) ~ testterm & term(:z) + term(:x)
    @test d0 ≊ merge(d, (yterm=term(:y), treatintterms=TermSet(term(:z)),
        xterms=TermSet(term(:x))))
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
    @test s[2] ≊ didspec(TestDID, TR, PR; yterm=term(:y), treatname=:g,
        treatintterms=TermSet(), xterms=TermSet())

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
    @test coef(r, :rel=>x->x==1) == [1.0, 2.0]
    @test coef(r, :rel=>x->x==1, :c=>x->x==1) == [1.0]
    @test coef(r, (:rel, :c)=>(x, y)->x==1) == [1.0, 2.0]

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
    @test vcov(r, :rel=>x->x==1) == r.vcov[[1,2], [1,2]]
    @test vcov(r, :rel=>x->x==1, :c=>x->x==1) == reshape([1.0], 1, 1)
    @test vcov(r, (:rel, :c)=>(x, y)->x==1) == r.vcov[[1,2], [1,2]]

    @test vce(r) === nothing
    cfint = confint(r)
    @test length(cfint) == 2
    @test all(cfint[1] + cfint[2] .≈ 2 * coef(r))

    @test treatment(r) === TR
    @test nobs(r) == 6
    @test outcomename(r) == "y"
    @test coefnames(r) == r.coefnames
    @test treatcells(r) == r.treatcells
    @test weights(r) == :w
    @test ntreatcoef(r) == 4
    @test treatcoef(r) == r.coef[1:4]
    @test treatvcov(r) == r.vcov[1:4, 1:4]
    @test treatnames(r) == r.coefnames[1:4]
    @test parent(r) === r
    @test dof_residual(r) == 5
    @test responsename(r) == "y"
    @test coefinds(r) == r.coefinds
    @test ncovariate(r) == 2

    @test_throws ErrorException agg(r)

    w = VERSION < v"1.6.0" ? " " : ""
    @test sprint(show, r) == """
        ─────────────────────────────────────────────────────────────────────────
                       Estimate  Std. Error     t  Pr(>|t|)  Lower 95%  Upper 95%
        ─────────────────────────────────────────────────────────────────────────
        rel: 1 & c: 1       1.0         1.0  1.00    0.3632   -1.57058    3.57058
        rel: 1 & c: 2       2.0         2.0  1.00    0.3632   -3.14116    7.14116
        rel: 2 & c: 1       3.0         3.0  1.00    0.3632   -4.71175   10.7117$w
        rel: 2 & c: 2       4.0         4.0  1.00    0.3632   -6.28233   14.2823$w
        c5                  5.0         5.0  1.00    0.3632   -7.85291   17.8529$w
        c6                  6.0         6.0  1.00    0.3632   -9.42349   21.4235$w
        ─────────────────────────────────────────────────────────────────────────"""
    
    r = TestResultBARE(2, 2)
    @test dof_residual(r) === nothing
    @test coefinds(r) === nothing

    w = VERSION < v"1.6.0" ? " " : ""
    @test sprint(show, r) == """
        ─────────────────────────────────────────────────────────────────────────
                       Estimate  Std. Error     z  Pr(>|z|)  Lower 95%  Upper 95%
        ─────────────────────────────────────────────────────────────────────────
        rel: 1 & c: 1       1.0         1.0  1.00    0.3173  -0.959964    2.95996
        rel: 1 & c: 2       2.0         2.0  1.00    0.3173  -1.91993     5.91993
        rel: 2 & c: 1       3.0         3.0  1.00    0.3173  -2.87989     8.87989
        rel: 2 & c: 2       4.0         4.0  1.00    0.3173  -3.83986    11.8399$w
        ─────────────────────────────────────────────────────────────────────────"""
end

@testset "_treatnames" begin
    t = VecColumnTable((rel=[1, 2],))
    @test _treatnames(t) == ["rel: 1", "rel: 2"]
    r = TestResult(2, 2)
    @test _treatnames(r.treatcells) == ["rel: $a & c: $b" for a in 1:2 for b in 1:2]
end

@testset "_parse_bycells!" begin
    cells = VecColumnTable((rel=repeat(1:2, inner=2), c=repeat(1:2, outer=2)))
    bycols = copy(getfield(cells, :columns))
    _parse_bycells!(bycols, cells, :rel=>isodd)
    @test bycols[1] == isodd.(cells.rel)
    @test bycols[2] === cells.c

    bycols = copy(getfield(cells, :columns))
    _parse_bycells!(bycols, cells, :rel=>:c=>isodd)
    @test bycols[1] == isodd.(cells.c)
    @test bycols[2] === cells.c

    bycols = copy(getfield(cells, :columns))
    _parse_bycells!(bycols, cells, (:rel=>1=>isodd, 2=>1=>isodd))
    @test bycols[1] == isodd.(cells.rel)
    @test bycols[2] == isodd.(cells.rel)

    bycols = copy(getfield(cells, :columns))
    _parse_bycells!(bycols, cells, nothing)
    @test bycols[1] == cells.rel
    @test bycols[2] == cells.c

    @test_throws ArgumentError _parse_bycells!(bycols, cells, (:rel,))
end

@testset "_parse_subset _nselected" begin
    r = TestResult(2, 2)
    @test _parse_subset(r, 1:4, true) == 1:4
    @test _parse_subset(r, collect(1:4), true) == 1:4
    @test _parse_subset(r, trues(4), true) == trues(4)
    @test _parse_subset(r, :rel=>isodd, true) == ((1:6) .< 3)
    @test _parse_subset(r, :rel=>isodd, false) == ((1:4) .< 3)
    @test _parse_subset(r, (:rel=>isodd, :c=>isodd), true) == ((1:6) .< 2)
    @test _parse_subset(r, (:rel=>isodd, :c=>isodd), false) == ((1:4) .<2)
    @test _parse_subset(r, :, false) == 1:4
    @test _parse_subset(r, :, true) == 1:6

    @test _nselected(1:10) == 10
    @test _nselected(collect(1:10)) == 10
    @test _nselected(isodd.(1:10)) == 5
    @test _nselected([true, false]) == 1
    @test_throws ArgumentError _nselected(:)
end

@testset "treatindex checktreatindex" begin
    @test treatindex(10, :) == 1:10
    @test treatindex(10, 1) == 1
    @test length(treatindex(10, 11)) == 0
    @test treatindex(10, 1:5) == 1:5
    @test treatindex(10, collect(1:20)) == 1:10
    @test treatindex(10, isodd.(1:20)) == isodd.(1:10)
    @test_throws ArgumentError treatindex(10, :a)

    @test checktreatindex([3,2,1,5,4], [1,2,3])
    @test checktreatindex(1:10, 1:5)
    @test_throws ArgumentError checktreatindex([3,2,1,5,4], [3,5])
    @test_throws ArgumentError checktreatindex(10:-1:1, 1:5)
    @test checktreatindex(trues(10), trues(5))
    @test checktreatindex(:, 1:5)
    @test checktreatindex(5, 1:0)
end

@testset "SubDIDResult" begin
    r = TestResult(2, 2)
    sr = view(r, :)
    @test coef(sr) == coef(r)
    @test vcov(sr) == vcov(r)
    @test vce(sr) === nothing
    @test treatment(sr) === TR
    @test nobs(sr) == nobs(r)
    @test outcomename(sr) == outcomename(r)
    @test coefnames(sr) == coefnames(r)
    @test treatcells(sr) == treatcells(r)
    @test weights(sr) == weights(r)
    @test ntreatcoef(sr) == ntreatcoef(r)
    @test treatcoef(sr) == treatcoef(r)
    @test treatvcov(sr) == treatvcov(r)
    @test treatnames(sr) == treatnames(r)
    @test parent(sr) === r
    @test dof_residual(sr) == dof_residual(r)
    @test responsename(sr) == responsename(r)
    @test coefinds(sr) == coefinds(r)
    @test ncovariate(sr) == 2

    sr = view(r, isodd.(1:6))
    @test coef(sr) == coef(r)[[1,3,5]]
    @test vcov(sr) == vcov(r)[[1,3,5],[1,3,5]]
    @test vce(sr) === nothing
    @test treatment(sr) === TR
    @test nobs(sr) == nobs(r)
    @test outcomename(sr) == outcomename(r)
    @test coefnames(sr) == coefnames(r)[[1,3,5]]
    @test treatcells(sr) == view(treatcells(r), [1,3])
    @test weights(sr) == weights(r)
    @test ntreatcoef(sr) == 2
    @test treatcoef(sr) == treatcoef(r)[[1,3]]
    @test treatvcov(sr) == treatvcov(r)[[1,3],[1,3]]
    @test treatnames(sr) == treatnames(r)[[1,3]]
    @test parent(sr) === r
    @test dof_residual(sr) == dof_residual(r)
    @test responsename(sr) == responsename(r)
    @test coefinds(sr) == Dict("rel: 1 & c: 1"=>1, "rel: 2 & c: 1"=>2, "c5"=>3)
    @test ncovariate(sr) == 1

    @test_throws BoundsError view(r, 1:7)
    @test_throws ArgumentError view(r, [6,1])
end

@testset "TransformedDIDResult" begin
    r = TestResult(2, 2)
    m = reshape(1:36, 6, 6)
    tr = TransformedDIDResult(r, m, copy(r.coef), copy(r.vcov))

    @test coef(tr) === tr.coef
    @test vcov(tr) === tr.vcov
    @test vce(tr) === nothing
    @test treatment(tr) === TR
    @test nobs(tr) == nobs(r)
    @test outcomename(tr) == outcomename(r)
    @test coefnames(tr) === coefnames(r)
    @test treatcells(tr) === treatcells(r)
    @test weights(tr) == weights(r)
    @test ntreatcoef(tr) == 4
    @test treatcoef(tr) == tr.coef[1:4]
    @test treatvcov(tr) == tr.vcov[1:4,1:4]
    @test treatnames(tr) == treatnames(r)
    @test parent(tr) === r
    @test dof_residual(tr) == dof_residual(r)
    @test responsename(tr) == responsename(r)
    @test coefinds(tr) === coefinds(r)
    @test ncovariate(tr) == 2
end

@testset "TransSubDIDResult" begin
    r = TestResult(2, 2)
    m = reshape(1:18, 3, 6)
    inds = [2,1,6]
    tr = TransSubDIDResult(r, m, r.coef[inds], r.vcov[inds, inds], inds)

    @test coef(tr) === tr.coef
    @test vcov(tr) === tr.vcov
    @test vce(tr) === nothing
    @test treatment(tr) === TR
    @test nobs(tr) == nobs(r)
    @test outcomename(tr) == outcomename(r)
    @test coefnames(tr) == coefnames(r)[inds]
    @test treatcells(tr) == view(treatcells(r), 2:-1:1)
    @test weights(tr) == weights(r)
    @test ntreatcoef(tr) == 2
    @test treatcoef(tr) == tr.coef[1:2]
    @test treatvcov(tr) == tr.vcov[1:2,1:2]
    @test treatnames(tr) == treatnames(r)[2:-1:1]
    @test parent(tr) === r
    @test dof_residual(tr) == dof_residual(r)
    @test responsename(tr) == responsename(r)
    @test coefinds(tr) === tr.coefinds
    @test ncovariate(tr) == 1

    @test_throws BoundsError TransSubDIDResult(r, m, r.coef[1:2], r.vcov[1:2,1:2], 1:7)
    @test_throws ArgumentError TransSubDIDResult(r, m, r.coef[1:2], r.vcov[1:2,1:2], [6,1])
end

@testset "lincom" begin
    r = TestResult(2, 2)
    m = reshape(1:36, 6, 6)
    tr = lincom(r, m)
    @test coef(tr) == m * r.coef
    @test vcov(tr) == m * r.vcov * m'

    tr = lincom(r, m, nothing)
    @test coef(tr) == m * r.coef
    @test vcov(tr) == m * r.vcov * m'
    @test tr isa TransformedDIDResult

    m = reshape(1:18, 3, 6)
    inds = [1,2,6]
    tr = lincom(r, m, inds)
    @test coef(tr) == m * r.coef
    @test vcov(tr) == m * r.vcov * m'

    m1 = reshape(1:15, 3, 5)
    @test_throws DimensionMismatch lincom(r, m1)
    @test_throws DimensionMismatch lincom(r, m1, 1:3)

    @test_throws ArgumentError lincom(r, m)
    @test_throws ArgumentError lincom(r, m, 1:6)
end

@testset "rescale" begin
    r = TestResult(2, 2)
    scale = fill(2, 6)
    m = Diagonal(scale)
    tr = rescale(r, scale)
    @test coef(tr) == m * r.coef
    @test vcov(tr) == m * r.vcov * m'

    tr = rescale(r, scale, nothing)
    @test coef(tr) == m * r.coef
    @test vcov(tr) == m * r.vcov * m'
    @test tr isa TransformedDIDResult

    scale = fill(2, 3)
    m = Diagonal(scale)
    inds = [1,2,6]
    tr = rescale(r, scale, inds)
    @test coef(tr) == m * r.coef[inds]
    @test vcov(tr) == m * r.vcov[inds,inds] * m'

    tr = rescale(r, :rel=>identity)
    @test coef(tr) == r.treatcells.rel.*r.coef[1:4]
    m = Diagonal(r.treatcells.rel)
    @test vcov(tr) == m * r.vcov[1:4,1:4] * m'

    tr = rescale(r, :rel=>identity, 1:3)
    @test coef(tr) == r.treatcells.rel[1:3].*r.coef[1:3]
    m = Diagonal(r.treatcells.rel[1:3])
    @test vcov(tr) == m * r.vcov[1:3,1:3] * m'
end

@testset "post!" begin
    @test getexportformat() == DefaultExportFormat[1]
    setexportformat!(StataPostHDF())
    @test DefaultExportFormat[1] == StataPostHDF()

    f = Dict{String,Any}()
    r = TestResult(2, 2)
    post!(f, r)
    @test f["model"] == "TestResult{TestTreatment}"
    @test f["b"] == coef(r)
    @test f["V"] == vcov(r)
    @test f["vce"] == "nothing"
    @test f["N"] == nobs(r)
    @test f["depvar"] == "y"
    @test f["coefnames"][1] == "rel: 1 & c: 1"
    @test f["weights"] == "w"
    @test f["ntreatcoef"] == 4

    f = Dict{String,Any}()
    fds = Union{Symbol, Pair{String,Symbol}}[Symbol("extra$i") for i in 1:8]
    fds[1] = "e1"=>:extra1
    post!(f, StataPostHDF(), r, model="test", fields=fds, at=1:6)
    @test f["e1"] == 1
    @test f["extra2"] == "a"
    @test f["extra3"] == "a"
    @test f["extra4"] == [1.0]
    @test f["extra5"] == ["a"]
    @test f["extra6"] == [1.0 2.0]
    @test f["extra7"] == ["a"]
    @test f["extra8"] == ""

    f = Dict{String,Any}()
    @test_throws ArgumentError post!(f, StataPostHDF(), r, fields=[:extra9])
    f = Dict{String,Any}()
    @test_throws ArgumentError post!(f, StataPostHDF(), r, at=false)
    f = Dict{String,Any}()
    @test_throws ArgumentError post!(f, StataPostHDF(), r, at=1:2)

    r1 = TestResultBARE(2, 2)
    f = Dict{String,Any}()
    post!(f, StataPostHDF(), r1, at=true)
    @test f["at"] == treatcells(r1).rel
    f = Dict{String,Any}()
    post!(f, StataPostHDF(), r1, at=false)
    @test !haskey(f, "at")
end
