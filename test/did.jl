using DiffinDiffsBase: parse_didargs
import DiffinDiffsBase: did

did(::TestDID, ::AbstractTreatment, ::AbstractParallel;
    treatstatus=:unknown, formula=nothing) = treatstatus

@testset "did wrapper" begin
    testterm = treat(:g, TR, PR)

    @testset "implemented" begin
        d1 = did(TestDID(), testterm)
        d2 = did(TestDID(), term(:y) ~ testterm)
        @test d1 == d2

        @test_throws MethodError did(TestDID(), testterm, 0)
        @test_throws MethodError did(TestDID(), term(:y) ~ testterm, 0)
        @test_throws MethodError did(TestDID(), term(:y) ~ testterm & term(:z))
        @test_throws MethodError did(TestDID(), testterm, a=1)
        @test_throws MethodError did(TestDID(), term(:y) ~ testterm, a=1)
    end
    
    @testset "not implemented" begin
        @test_throws ErrorException did(NotImplemented(), TR, PR)
        @test_throws ErrorException did(NotImplemented(), testterm)
        @test_throws ErrorException did(NotImplemented(), term(:y) ~ testterm)
        @test_throws ErrorException did(NotImplemented(), term(:y) ~ testterm & term(:z))
        @test_throws ErrorException did(NotImplemented(), testterm, a=1)
        @test_throws ErrorException did(NotImplemented(), term(:y) ~ testterm, a=1)
        @test_throws ErrorException did(NotImplemented(), term(:y) ~ testterm & term(:z), a=1)

        @test_throws MethodError did(NotImplemented(), TR, PR, 0)
        @test_throws MethodError did(NotImplemented(), testterm, 0)
        @test_throws MethodError did(NotImplemented(), term(:y) ~ testterm, 0)
    end
end

@testset "parse_didargs" begin
    @test parse_didargs() == (Dict{Symbol,Any}(), Pair{Symbol,Any}[])
    args, kwargs = parse_didargs(TestDID(), TR, PR, a=1, b=2)
    @test args[:d] == TestDID()
    @test args[:tr] == TR
    @test args[:pr] == PR
    @test kwargs == [:a=>1, :b=>2]
    @test_throws ErrorException parse_didargs("a", :a, 1)
end

@testset "spec" begin
    sp0 = DIDSpec(Symbol(""), Dict(:d=>TestDID(), :tr=>TR, :pr=>PR),
        Pair{Symbol,Any}[:a=>1, :b=>2])
    sp1 = spec(TestDID(), TR, PR, a=1, b=2)
    @test sp1 == sp0

    sp0 = DIDSpec(:name, Dict(:d=>TestDID(), :tr=>TR, :pr=>PR),
        Pair{Symbol,Any}[:a=>1, :b=>2])
    sp1 = spec("name", TestDID(), TR, PR, a=1, b=2)
    @test sp1 == sp0
end

@testset "@did" begin
    d0 = @did TestDID() TR PR
    d1 = @did PR TR TestDID()
    @test d0 == :unknown
    @test d1 == d0

    @test_throws ErrorException @did TestDID()
    @test_throws ErrorException @did TestDID() TR PR PR
    @test_throws ErrorException @did TestDID() TR PR PR 1
    @test_throws ErrorException @did TestDID() TR PR PR "test"
    @test_throws ErrorException @did NotImplemented() TR PR
end
