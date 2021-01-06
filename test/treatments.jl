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
    dt = DynamicTreatment(:month, SharpDesign())

    @testset "without @formula" begin
        @test dynamic(:month) == dt
        @test dynamic(:month, sharp()) == dt
    end

    @testset "with @formula" begin
        @test dynamic(term(:month)) == dt
        @test dynamic(term(:month), term(:sharp)) == dt

        f = @formula(y ~ treat(g, dynamic(month), tpara(0)))
        t = parse_treat(f)[1]
        @test t.tr == dt

        f = @formula(y ~ treat(g, dynamic(month, sharp), tpara(0)))
        t = parse_treat(f)[1]
        @test t.tr == dt
    end

    @testset "show" begin
        @test sprint(show, dt) == """
            Sharp dynamic treatment:
              column name of time variable: month
            """
        @test sprint(show, dt; context=:compact => true) ==
            "Dynamic{S}"
    end
end