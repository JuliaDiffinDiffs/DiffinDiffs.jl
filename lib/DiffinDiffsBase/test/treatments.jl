@testset "singletons" begin
    @testset "alias" begin
        @test sharp() == SharpDesign()
    end

    @testset "show" begin
        @test sprint(show, SharpDesign()) == "Sharp"
        @test sprintcompact(SharpDesign()) == "S"
    end
end

@testset "dynamic" begin
    dt0 = DynamicTreatment(:month, nothing, SharpDesign())
    dt1 = DynamicTreatment(:month, -1, SharpDesign())
    dt2 = DynamicTreatment(:month, [-2,-1], SharpDesign())

    @testset "inner constructor" begin
        @test DynamicTreatment(:month, [], SharpDesign()) == dt0
        @test DynamicTreatment(:month, [-1], SharpDesign()) == dt1
        @test DynamicTreatment(:month, [-1,-1,-2], SharpDesign()) == dt2
        @test DynamicTreatment(:month, [-1.0], SharpDesign()) == dt1
        @test_throws InexactError DynamicTreatment(:month, [-1.5], SharpDesign())
    end

    @testset "without @formula" begin
        @test dynamic(:month, nothing) == dt0
        @test dynamic(:month, []) == dt0
        @test dynamic(:month, -1) == dt1
        @test dynamic(:month, [-1], sharp()) == dt1
        @test dynamic(:month, -2:-1) == dt2
        @test dynamic(:month, Set([-1,-2]), sharp()) == dt2
    end

    @testset "with @formula" begin
        @test dynamic(term(:month), term(-1)) == dt1
        @test dynamic(term(:month), term(-1), term(:sharp)) == dt1

        f = @formula(y ~ treat(g, dynamic(month, nothing), tpara(0)))
        t = parse_treat(f)[1]
        @test t.tr == dt0

        f = @formula(y ~ treat(g, dynamic(month, cb), tpara(0)))
        t = parse_treat(f)[1]
        @test t.tr == dt0

        f = @formula(y ~ treat(g, dynamic(month, -1), tpara(0)))
        t = parse_treat(f)[1]
        @test t.tr == dt1

        f = @formula(y ~ treat(g, dynamic(month, cb(-1)), tpara(0)))
        t = parse_treat(f)[1]
        @test t.tr == dt1

        f = @formula(y ~ treat(g, dynamic(month, cb(-1,-2), sharp), tpara(0)))
        t = parse_treat(f)[1]
        @test t.tr == dt2
    end

    @testset "show" begin
        @test sprint(show, dt0) == "Dynamic{S}()"
        @test sprint(show, MIME("text/plain"), dt0) == """
            Sharp dynamic treatment:
              column name of time variable: month
              excluded relative time: none"""

        @test sprint(show, dt1) == "Dynamic{S}(-1)"
        @test sprint(show, MIME("text/plain"), dt1) == """
            Sharp dynamic treatment:
              column name of time variable: month
              excluded relative time: -1"""

        @test sprint(show, dt2) == "Dynamic{S}(-2, -1)"
        @test sprint(show, MIME("text/plain"), dt2) == """
            Sharp dynamic treatment:
              column name of time variable: month
              excluded relative time: -2, -1"""
    end
end

@testset "termvars" begin
    @test termvars(sharp()) == Symbol[]
    @test termvars(dynamic(:month, -1)) == [:month]

    @test_throws ErrorException termvars(TestSharpness())
    @test_throws ErrorException termvars(TR)
end
