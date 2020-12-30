const t0 = TreatmentTerm(:g, TestTreatment(:t, 0), TestParallel(0))
const t1 = treat(:g, TestTreatment(:t, 0), TestParallel(0))
const t2 = treat(:g, TestTreatment(:t, 1), TestParallel(0))
const t3 = treat(:g, TestTreatment(:t, 0), TestParallel(1))

@testset "treat" begin    
    @test t1 == t0
    @test t2 != t0
    @test t3 != t0
end

@testset "parse_treat" begin
    @testset "with @formula" begin
        f = @formula(y ~ x)
        @test_throws ArgumentError parse_treat(f)

        f = @formula(y ~ treat(g, testtreat(t, 0), testpara(0)) + x & z + lag(x,1))
        t = parse_treat(f)
        @test t == (t1=>())

        f = @formula(y ~ treat(g, testtreat(t, 0), testpara(0)) & x & z)
        t = parse_treat(f)
        @test t == (t1=>(term(:x), term(:z)))

        f = @formula(y ~ treat(g, testtreat(t, 0), testpara(0)) & treat(g, testtreat(t, 0), testpara(0)))
        @test_throws ArgumentError parse_treat(f)

        f = @formula(y ~ treat(g, testtreat(t, 0), testpara(0)) & treat(g, testtreat(t, 1), testpara(0)))
        @test_throws ArgumentError parse_treat(f)

        f = @formula(y ~ treat(g, testtreat(t, 0), testpara(0)) + treat(g, testtreat(t, 0), testpara(0)))
        @test_throws ArgumentError parse_treat(f)

        f = @formula(y ~ treat(g, testtreat(t, 0), testpara(0)) + treat(g, testtreat(t, 1), testpara(0)))
        @test_throws ArgumentError parse_treat(f)

        f = @formula(y ~ treat(g, testtreat(t, 0), testpara(0)) & x + treat(g, testtreat(t, 0), testpara(0)) & z)
        @test_throws ArgumentError parse_treat(f)
    end

    @testset "without @formula" begin
        f = term(:y) ~ term(:x)
        @test_throws ArgumentError parse_treat(f)

        f = term(:y) ~ treat(:g, TestTreatment(:t, 0), TestParallel(0)) + term(:x) & term(:z) + lag(term(:x),1)
        t = parse_treat(f)
        @test t == (t1=>())

        f = term(:y) ~ treat(:g, TestTreatment(:t, 0), TestParallel(0)) & term(:x) & term(:z)
        t = parse_treat(f)
        @test t == (t1=>(term(:x), term(:z)))

        f = term(:y) ~ treat(:g, TestTreatment(:t, 0), TestParallel(0)) & treat(:g, TestTreatment(:t, 0), TestParallel(0))
        @test_throws ArgumentError parse_treat(f)

        f = term(:y) ~ treat(:g, TestTreatment(:t, 0), TestParallel(0)) & treat(:g, TestTreatment(:t, 1), TestParallel(0))
        @test_throws ArgumentError parse_treat(f)

        # + checks uniqueness of terms
        f = term(:y) ~ treat(:g, TestTreatment(:t, 0), TestParallel(0)) + treat(:g, TestTreatment(:t, 0), TestParallel(0))
        @test f == (term(:y) ~ treat(:g, TestTreatment(:t, 0), TestParallel(0)))

        f = term(:y) ~ treat(:g, TestTreatment(:t, 0), TestParallel(0)) + treat(:g, TestTreatment(:t, 1), TestParallel(0))
        @test_throws ArgumentError parse_treat(f)

        f = term(:y) ~ treat(:g, TestTreatment(:t, 0), TestParallel(0)) & term(:x) +
            treat(:g, TestTreatment(:t, 0), TestParallel(0)) & term(:z)
        @test_throws ArgumentError parse_treat(f)
    end
end
