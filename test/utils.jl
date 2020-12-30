@testset "c" begin
    f = @formula(y ~ c(1))
    @test f.rhs.forig(f.rhs.args_parsed...) == [1]

    f = @formula(y ~ c(1,2))
    @test f.rhs.forig(f.rhs.args_parsed...) == [1,2]

    f = @formula(y ~ c(1,x))
    @test_throws ArgumentError f.rhs.forig(f.rhs.args_parsed...)
end

@testset "exampledata" begin
    @test exampledata() == ["hrs"]
    @test size(exampledata(:hrs),1) == 3280
end
