@testset "_parsefeterm" begin
    @test _parsefeterm(term(:male)) === nothing
    @test _parsefeterm(fe(:hhidpn)) == ([:hhidpn]=>Symbol[])
    @test _parsefeterm(fe(:hhidpn)&fe(:wave)&term(:male)) == ([:hhidpn, :wave]=>[:male])
end

@testset "getfename" begin
    @test getfename([:hhidpn]=>Symbol[]) == "fe_hhidpn"
    @test getfename([:hhidpn, :wave]=>[:male]) == "fe_hhidpn&fe_wave&male"
end
