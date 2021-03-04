const t0 = TreatmentTerm(:g, TestTreatment(:t, 0), TestParallel(0))
const t1 = treat(:g, TestTreatment(:t, 0), TestParallel(0))
const t2 = treat(:g, TestTreatment(:t, 1), TestParallel(0))
const t3 = treat(:g, TestTreatment(:t, 0), TestParallel(1))

@testset "==" begin
    @test term(:x) + term(:y) == term(:y) + term(:x)
    @test term(:x) + term(:y) + term(:y) == term(:y) + term(:x) + term(:x)

    @test term(:x) & term(:y) == term(:y) & term(:x)
    @test term(:x) & term(:y) + term(:y) & term(:x) == term(:y) & term(:x)
    @test term(:x) & term(:y) + term(:z) == term(:z) + term(:y) & term(:x)
    @test lag(term(:x),1) & term(:z) == term(:z) & lag(term(:x),1)
    # StatsModels does not enforce uniqueness of terms in interactions
    @test term(:x) & term(:y) & term(:x) != term(:x) & term(:y)

    @test @formula(y ~ x + z) == @formula(y ~ z + x)
    @test @formula(y ~ t & z + x) == @formula(y ~ x + z & t)
    @test @formula(y ~ lag(x, 1)&z + t) == @formula(y ~ t + z&lag(x, 1))
end

@testset "treat" begin
    @test t1 == t0
    @test t2 != t0
    @test t3 != t0
end

@testset "hastreat" begin
    @test hastreat(t0)

    f0 = @formula(y ~ x)
    f1 = @formula(y ~ treat(g, ttreat(t, 0), tpara(0)))
    f2 = @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & x)

    @test hastreat(f0.rhs) == false
    @test hastreat(f1.rhs)
    @test hastreat(f2.rhs)

    @test hastreat(f0) == false
    @test hastreat(f1)
    @test hastreat(f2)
end

@testset "parse_treat" begin
    @testset "with @formula" begin
        f = @formula(y ~ x)
        @test_throws ArgumentError parse_treat(f)

        f = @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) + x & z)
        t = parse_treat(f)
        @test t == (t1, TermSet(), TermSet(term(:x)&term(:z)=>nothing))

        f = @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & x & z)
        t = parse_treat(f)
        @test t == (t1, TermSet((term(:x), term(:z)).=>nothing), TermSet())

        f = @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & treat(g, ttreat(t, 0), tpara(0)))
        @test_throws ArgumentError parse_treat(f)

        f = @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & treat(g, ttreat(t, 1), tpara(0)))
        @test_throws ArgumentError parse_treat(f)

        # + checks uniqueness of terms
        f = @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) + treat(g, ttreat(t, 0), tpara(0)))
        @test f == @formula(y ~ treat(g, ttreat(t, 0), tpara(0)))

        f = @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) + treat(g, ttreat(t, 1), tpara(0)))
        @test_throws ArgumentError parse_treat(f)

        f = @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & x + treat(g, ttreat(t, 0), tpara(0)) & z)
        @test_throws ArgumentError parse_treat(f)
    end

    @testset "without @formula" begin
        f = term(:y) ~ term(:x)
        @test_throws ArgumentError parse_treat(f)

        f = term(:y) ~ treat(:g, TR, PR) + term(:x) & term(:z) + lag(term(:x),1)
        t = parse_treat(f)
        @test t == (t1, TermSet(), TermSet((term(:x) & term(:z) + lag(term(:x),1).=>nothing)))

        f = term(:y) ~ treat(:g, TR, PR) & term(:x) & term(:z)
        t = parse_treat(f)
        @test t == (t1, TermSet((term(:x), term(:z)).=>nothing), TermSet())

        f = term(:y) ~ treat(:g, TR, PR) & treat(:g, TR, PR)
        @test_throws ArgumentError parse_treat(f)

        f = term(:y) ~ treat(:g, TR, PR) & treat(:g, TestTreatment(:t, 1), PR)
        @test_throws ArgumentError parse_treat(f)

        # + checks uniqueness of terms
        f = term(:y) ~ treat(:g, TR, PR) + treat(:g, TR, PR)
        @test f == (term(:y) ~ treat(:g, TR, PR))

        f = term(:y) ~ treat(:g, TR, PR) + treat(:g, TestTreatment(:t, 1), PR)
        @test_throws ArgumentError parse_treat(f)

        f = term(:y) ~ treat(:g, TR, PR) & term(:x) +
            treat(:g, TR, PR) & term(:z)
        @test_throws ArgumentError parse_treat(f)
    end
end

@testset "parse_intercept!" begin
    @test isintercept(term(1))
    @test isomitsintercept(term(0))
    @test isomitsintercept(term(-1))

    @test parse_intercept!(TermSet()) == (false, false)
    @test parse_intercept!(TermSet(term(:x)=>nothing)) == (false, false)
    ts = TermSet(term(1)=>nothing)
    @test parse_intercept!(ts) == (true, false)
    @test collect(keys(ts))[1] == InterceptTerm{true}()
    ts = TermSet((term(0), term(-1)).=>nothing)
    @test parse_intercept!(ts) == (false, true)
    @test collect(keys(ts))[1] == InterceptTerm{false}()
    ts = TermSet((term(1), term(0), term(:x)).=>nothing)
    @test parse_intercept!(ts) == (true, true)
    @test haskey(ts, term(:x)) && haskey(ts, InterceptTerm{false}()) &&
        haskey(ts, InterceptTerm{true}())
end
