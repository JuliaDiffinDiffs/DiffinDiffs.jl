using DiffinDiffsBase: parse_didargs
import DiffinDiffsBase: did

did(::Type{TestDID}, ::AbstractTreatment, ::AbstractParallel;
    yterm=:unknown, treatname=:unknown, treatintterms=nothing, xterms=nothing) =
        (yterm, treatname, treatintterms, xterms)

const testterm = treat(:g, TR, PR)

@testset "did wrapper" begin
    @testset "DefaultDID" begin
        @test_throws ErrorException did(TR, PR)
    end

    @testset "implemented" begin
        d0 = did(TestDID, TR, PR)
        @test d0 == (:unknown, :unknown, nothing, nothing)
        d1 = did(TestDID, testterm)
        @test d1 == (:unknown, :g, nothing, nothing)
        d2 = did(TestDID, term(:y) ~ testterm)
        @test d2 == (term(:y), :g, nothing, nothing)
        d3 = did(TestDID, term(:y) ~ testterm & term(:z) + term(:x))
        @test d3 == (term(:y), :g, (term(:z),), (term(:x),))

        d4 = did(TestDID, @formula(y ~ treat(g, ttreat(t, 0), tpara(0))))
        @test d4 == d2
        d5 = did(TestDID, @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x))
        @test d5 ==d3

        @test_throws MethodError did(TestDID)
        @test_throws MethodError did(TestDID, testterm, 0)
        @test_throws MethodError did(TestDID, term(:y) ~ testterm, 0)
        @test_throws MethodError did(TestDID, testterm, a=1)
        @test_throws MethodError did(TestDID, term(:y) ~ testterm, a=1)
    end
    
    @testset "not implemented" begin
        @test_throws ErrorException did(NotImplemented, TR, PR)
        @test_throws ErrorException did(NotImplemented, testterm)
        @test_throws ErrorException did(NotImplemented, term(:y) ~ testterm)
        @test_throws ErrorException did(NotImplemented, term(:y) ~ testterm & term(:z))
        @test_throws ErrorException did(NotImplemented, testterm, a=1)
        @test_throws ErrorException did(NotImplemented, term(:y) ~ testterm, a=1)
        @test_throws ErrorException did(NotImplemented, term(:y) ~ testterm & term(:z), a=1)

        @test_throws MethodError did(NotImplemented, TR, PR, 0)
        @test_throws MethodError did(NotImplemented, testterm, 0)
        @test_throws MethodError did(NotImplemented, term(:y) ~ testterm, 0)
    end
end

@testset "parse_didargs" begin
    @test parse_didargs() == ("", Dict{Symbol,Any}(), Dict{Symbol,Any}())
    @test parse_didargs("test") == ("test", Dict{Symbol,Any}(), Dict{Symbol,Any}())

    name, args, kwargs = parse_didargs(TestDID, TR, PR, a=1, b=2)
    @test name == ""
    @test args == Dict(:d=>TestDID, :tr=>TR, :pr=>PR)
    @test kwargs == Dict(:a=>1, :b=>2)

    name, args, kwargs = parse_didargs("test", testterm, TestDID)
    @test name == "test"
    @test args == Dict(:d=>TestDID, :tr=>TR, :pr=>PR)
    @test kwargs == Dict(:treatname=>:g)

    name, args0, kwargs0 = parse_didargs(TestDID, term(:y) ~ testterm, "test")
    @test name == "test"
    @test args0 == Dict(:d=>TestDID, :tr=>TR, :pr=>PR)
    @test kwargs0 == Dict(:yterm=>term(:y), :treatname=>:g)

    name, args1, kwargs1 = parse_didargs(TestDID, @formula(y ~ treat(g, ttreat(t, 0), tpara(0))))
    @test name == ""
    @test args1 == args0
    @test kwargs1 == kwargs0

    name, args0, kwargs0 = parse_didargs(TestDID, term(:y) ~ testterm & term(:z) + term(:x))
    @test args0 == Dict(:d=>TestDID, :tr=>TR, :pr=>PR)
    @test kwargs0 == Dict(:yterm=>term(:y), :treatname=>:g,
        :treatintterms=>(term(:z),), :xterms=>(term(:x),))
    
    name, args1, kwargs1 = parse_didargs(TestDID,
        @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x))
    @test args1 == args0
    @test kwargs1 == kwargs0

    @test_throws ArgumentError parse_didargs('a', :a, 1)
end

@testset "spec @spec" begin
    testname = "name"

    sp = DIDSpec("", Dict{Symbol,Any}(), Dict{Symbol,Any}())
    @test spec() == sp
    @test sp.name == ""

    sp = DIDSpec("name", Dict{Symbol,Any}(), Dict{Symbol,Any}())
    @test spec("") == sp
    @test sp.name == "name"

    sp = @spec
    @test sp == spec()
    @test sp.name == ""

    sp = @spec "name"
    @test sp == spec()
    @test sp.name == "name"

    sp = @spec testname
    @test sp == spec()
    @test sp.name == "name"

    sp0 = DIDSpec("", Dict(:d=>TestDID, :tr=>TR, :pr=>PR), Dict(:a=>1, :b=>2))
    sp1 = spec(TestDID, TR, PR, a=1, b=2)
    @test sp1 == sp0
    @test sp0 == @spec TR a=1 b=2 PR TestDID

    sp2 = DIDSpec("name", Dict(:d=>TestDID, :tr=>TR, :pr=>PR), Dict(:a=>1, :b=>2))
    sp3 = spec("name", TR, PR, TestDID, b=2, a=1)
    @test sp3 == sp2
    @test sp3 == sp1
    @test sp2 == @spec TR PR TestDID "name" b=2 a=1

    sp4 = DIDSpec(testname, Dict(:d=>TestDID, :tr=>TR, :pr=>PR), Dict(:treatname=>:g))
    sp5 = spec(TestDID, testterm)
    @test sp5 == sp4
    @test sp4 == @spec TestDID testterm testname

    sp6 = DIDSpec("name", Dict(:d=>TestDID, :tr=>TR, :pr=>PR),
        Dict(:yterm=>term(:y), :treatname=>:g,
        :treatintterms=>(term(:z),), :xterms=>(term(:x),)))
    sp7 = spec(TestDID, term(:y) ~ testterm & term(:z) + term(:x))
    sp8 = spec(TestDID, @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x))
    @test sp7 == sp6
    @test sp8 == sp7
    @test sp6 == @spec TestDID term(:y) ~ testterm & term(:z) + term(:x)
    @test sp6 == @spec TestDID @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x)
end

@testset "@did" begin
    d0 = @did TestDID TR PR
    d1 = @did PR TR TestDID
    @test d0 == (:unknown, :unknown, nothing, nothing)
    @test d1 == d0

    d2 = @did TestDID testterm
    @test d2 == (:unknown, :g, nothing, nothing)
    d3 = @did TestDID term(:y) ~ testterm
    @test d3 == (term(:y), :g, nothing, nothing)
    d4 = @did TestDID term(:y) ~ testterm & term(:z) + term(:x)
    @test d4 == (term(:y), :g, (term(:z),), (term(:x),))
    d5 = @did TestDID @formula(y ~ treat(g, ttreat(t, 0), tpara(0))) "test"
    @test d5 == d3
    d6 = @did "test" TestDID @formula(y ~ treat(g, ttreat(t, 0), tpara(0)) & z + x)
    @test d6 ==d4

    @test_throws ArgumentError @did TestDID
    @test_throws ArgumentError @did TestDID TR
    @test_throws ArgumentError @did TestDID TR PR PR
    @test_throws ArgumentError @did TestDID TR PR 1
    @test_throws ErrorException @did NotImplemented TR PR
end
