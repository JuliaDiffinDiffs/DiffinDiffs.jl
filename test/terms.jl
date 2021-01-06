const t0 = TreatmentTerm(:g, TestTreatment(:t, 0), TestParallel(0))
const t1 = treat(:g, TestTreatment(:t, 0), TestParallel(0))
const t2 = treat(:g, TestTreatment(:t, 1), TestParallel(0))
const t3 = treat(:g, TestTreatment(:t, 0), TestParallel(1))

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

        f = @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) + x & z + lag(x,1))
        t = parse_treat(f)
        @test t == (t1=>())

        f = @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & x & z)
        t = parse_treat(f)
        @test t == (t1=>(term(:x), term(:z)))

        f = @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & treat(g, ttreat(t, 0), tpara(0)))
        @test_throws ArgumentError parse_treat(f)

        f = @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & treat(g, ttreat(t, 1), tpara(0)))
        @test_throws ArgumentError parse_treat(f)

        f = @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) + treat(g, ttreat(t, 0), tpara(0)))
        @test_throws ArgumentError parse_treat(f)

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
        @test t == (t1=>())

        f = term(:y) ~ treat(:g, TR, PR) & term(:x) & term(:z)
        t = parse_treat(f)
        @test t == (t1=>(term(:x), term(:z)))

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
