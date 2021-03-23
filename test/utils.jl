@testset "parse_fixedeffect!" begin
    hrs = exampledata(:hrs)

    @test parse_fixedeffect!(hrs, TermSet()) == (FixedEffect[], Symbol[], false)
    ts = TermSet((term(1),term(:male)))
    @test parse_fixedeffect!(hrs, ts) == (FixedEffect[], Symbol[], false)

    ts = TermSet(term(1)+term(:male)+fe(:hhidpn))
    @test parse_fixedeffect!(hrs, ts) == ([FixedEffect(hrs.hhidpn)], [:fe_hhidpn], true)
    @test ts == TermSet((InterceptTerm{false}(), term(:male)))

    # Verify that fes are sorted by name
    ts = TermSet(fe(:wave)+fe(:hhidpn))
    @test parse_fixedeffect!(hrs, ts) == ([FixedEffect(hrs.hhidpn), FixedEffect(hrs.wave)],
        [:fe_hhidpn, :fe_wave], true)
    @test ts == TermSet(InterceptTerm{false}())

    # Verify that no change is made on intercept
    ts = TermSet((term(:male), fe(:hhidpn)&term(:wave)))
    ret = parse_fixedeffect!(hrs, ts)
    @test ret[2] == [Symbol("fe_hhidpn&wave")]
    @test ts == TermSet(term(:male))
end
