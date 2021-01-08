@testset "singletons" begin
    @testset "alias" begin
        @test sharp() == SharpDesign()
    end

    @testset "show" begin
        @test sprint(show, SharpDesign()) == "Sharp"
        @test sprint(show, SharpDesign(); context=:compact => true) == "S"
    end
end

@testset "dynamic" begin
    dt0 = DynamicTreatment(:month, -1, SharpDesign())
    dt1 = DynamicTreatment(:month, [-2,-1], SharpDesign())

    @testset "inner constructor" begin
        @test DynamicTreatment(:month, [-1], SharpDesign()) == dt0
        @test DynamicTreatment(:month, [-1,-2], SharpDesign()) == dt1
    end

    @testset "without @formula" begin
        @test dynamic(:month, -1) == dt0
        @test dynamic(:month, -2:-1) == dt1
        @test dynamic(:month, [-1], sharp()) == dt0
        @test dynamic(:month, Set([-1,-2]), sharp()) == dt1
    end

    @testset "with @formula" begin
        @test dynamic(term(:month), term(-1)) == dt0
        @test dynamic(term(:month), term(-1), term(:sharp)) == dt0

        f = @formula(y ~ treat(g, dynamic(month, -1), tpara(0)))
        t = parse_treat(f)[1]
        @test t.tr == dt0

        f = @formula(y ~ treat(g, dynamic(month, c(-1)), tpara(0)))
        t = parse_treat(f)[1]
        @test t.tr == dt0

        f = @formula(y ~ treat(g, dynamic(month, c(-1,-2), sharp), tpara(0)))
        t = parse_treat(f)[1]
        @test t.tr == dt1
    end

    @testset "show" begin
        @test sprint(show, dt0) == """
            Sharp dynamic treatment:
              column name of time variable: month
              excluded relative time: -1
            """
        @test sprint(show, dt0; context=:compact => true) ==
            "Dynamic{S}(-1)"
        @test sprint(show, dt1) == """
            Sharp dynamic treatment:
              column name of time variable: month
              excluded relative time: [-2, -1]
            """
        @test sprint(show, dt1; context=:compact => true) ==
            "Dynamic{S}([-2, -1])"
    end
end
