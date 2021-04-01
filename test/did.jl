@testset "RegressionBasedDID" begin
    hrs = exampledata("hrs")
    r = @did(Reg, data=hrs, dynamic(:wave, -1), notyettreated(11),
        vce=Vcov.cluster(:hhidpn), yterm=term(:oop_spend), treatname=:wave_hosp,
        treatintterms=(), xterms=(fe(:wave)+fe(:hhidpn)), solvelsweights=true)
    # Compare estimates with Stata
    @test coef(r, "wave_hosp: 8 & rel: 0") ≈ 2825.5659 atol=1e-4
    @test coef(r, "wave_hosp: 8 & rel: 1") ≈ 825.14585 atol=1e-5
    @test coef(r, "wave_hosp: 8 & rel: 2") ≈ 800.10647 atol=1e-5
    @test coef(r, "wave_hosp: 9 & rel: -2") ≈ 298.97735 atol=1e-5
    @test coef(r, "wave_hosp: 9 & rel: 0") ≈ 3030.8408 atol=1e-4
    @test coef(r, "wave_hosp: 9 & rel: 1") ≈ 106.83785 atol=1e-5
    @test coef(r, "wave_hosp: 10 & rel: -3") ≈ 591.04639 atol=1e-5
    @test coef(r, "wave_hosp: 10 & rel: -2") ≈ 410.58102 atol=1e-5
    @test coef(r, "wave_hosp: 10 & rel: 0") ≈ 3091.5084 atol=1e-4

    @test coef(r) === r.coef
    @test vcov(r) === r.vcov
    @test vce(r) === r.vce
    @test nobs(r) == 2624
    @test outcomename(r) == "oop_spend"
    @test coefnames(r) == ["wave_hosp: $w & rel: $r"
        for (w, r) in zip(repeat(8:10, inner=3), [0, 1, 2, -2, 0, 1, -3, -2, 0])]
    @test treatcells(r) == r.treatcells
    @test weights(r) === nothing
    @test ntreatcoef(r) == 9
    @test treatcoef(r) == coef(r)
    @test treatvcov(r) == vcov(r)
    @test treatnames(r) == coefnames(r)
    @test dof_residual(r) == 2610
    @test responsename(r) == "oop_spend"
    @test coefinds(r) == r.coefinds
    @test ncovariate(r) == 0

    @test r.ycellweights == r.ycellcounts
    @test r.ycellcounts == repeat([252, 176, 163, 65], inner=4)
    @test all(i->r.coef[i]≈sum(r.lsweights[:,i].*r.ycellmeans), 1:ntreatcoef(r))

    @test sprint(show, r) == "Regression-based DID result"
    pv = VERSION < v"1.6.0" ? " <1e-7" : "<1e-07"
    @test sprint(show, MIME("text/plain"), r) == """
        ──────────────────────────────────────────────────────────────────────
        Summary of results: Regression-based DID
        ──────────────────────────────────────────────────────────────────────
        Number of obs:               2624    Degrees of freedom:            14
        F-statistic:                 6.42    p-value:                   $pv
        ──────────────────────────────────────────────────────────────────────
        Cohort-interacted sharp dynamic specification
        ──────────────────────────────────────────────────────────────────────
        Number of cohorts:              3    Interactions within cohorts:    0
        Relative time periods:          5    Excluded periods:              -1
        ──────────────────────────────────────────────────────────────────────
        Fixed effects: fe_hhidpn fe_wave
        ──────────────────────────────────────────────────────────────────────
        Converged:                   true    Singletons dropped:             0
        ──────────────────────────────────────────────────────────────────────"""

    r = @did(Reg, data=hrs, dynamic(:wave, -1), notyettreated([11]),
        vce=Vcov.cluster(:hhidpn), yterm=term(:oop_spend), treatname=:wave_hosp,
        treatintterms=(), cohortinteracted=false, lswtnames=(:wave_hosp, :wave))
    @test all(i->r.coef[i]≈sum(r.lsweights[:,i].*r.ycellmeans), 1:ntreatcoef(r))

    @test sprint(show, MIME("text/plain"), r) == """
        ──────────────────────────────────────────────────────────────────────
        Summary of results: Regression-based DID
        ──────────────────────────────────────────────────────────────────────
        Number of obs:               2624    Degrees of freedom:             6
        F-statistic:                12.50    p-value:                   <1e-10
        ──────────────────────────────────────────────────────────────────────
        Sharp dynamic specification
        ──────────────────────────────────────────────────────────────────────
        Relative time periods:          5    Excluded periods:              -1
        ──────────────────────────────────────────────────────────────────────
        Fixed effects: none
        ──────────────────────────────────────────────────────────────────────"""

    sr = view(r, 1:3)
    @test coef(sr)[1] ≈ 1560.2174484214308
    @test vcov(sr)[1] ≈ 1.1248572269146878e6
    @test parent(sr) === r

    tr = rescale(r, fill(2, 5), 1:5)
    @test coef(tr)[1] ≈ 2 * coef(sr)[1]
    @test vcov(tr)[1] ≈ 4 * vcov(sr)[1]
end

@testset "AggregatedRegBasedDIDResult" begin
    hrs = exampledata("hrs")
    r = @did(Reg, data=hrs, dynamic(:wave, -1), notyettreated(11),
        vce=Vcov.cluster(:hhidpn), yterm=term(:oop_spend), treatname=:wave_hosp,
        treatintterms=(), xterms=(fe(:wave)+fe(:hhidpn)))
    a = agg(r)
    @test coef(a) == coef(r)
    @test vcov(a) == vcov(r)
    @test vce(a) == vce(r)
    @test nobs(a) == nobs(r)
    @test outcomename(a) == outcomename(r)
    @test coefnames(a) === a.coefnames
    @test treatcells(a) === a.treatcells
    @test weights(a) == weights(r)
    @test ntreatcoef(a) == 9
    @test treatcoef(a) == coef(a)
    @test treatvcov(a) == vcov(a)
    @test treatnames(a) == a.coefnames
    @test parent(a) === r
    @test dof_residual(a) == dof_residual(r)
    @test responsename(a) == "oop_spend"
    @test coefinds(a) === a.coefinds
    @test ncovariate(a) == 0

    pv = VERSION < v"1.6.0" ? "<1e-4 " : "<1e-04"
    @test sprint(show, a) === """
        ───────────────────────────────────────────────────────────────────────────────────
                                 Estimate  Std. Error     t  Pr(>|t|)  Lower 95%  Upper 95%
        ───────────────────────────────────────────────────────────────────────────────────
        wave_hosp: 8 & rel: 0    2825.57     1038.18   2.72    0.0065    789.825    4861.31
        wave_hosp: 8 & rel: 1     825.146     912.101  0.90    0.3657   -963.368    2613.66
        wave_hosp: 8 & rel: 2     800.106    1010.81   0.79    0.4287  -1181.97     2782.18
        wave_hosp: 9 & rel: -2    298.977     967.362  0.31    0.7573  -1597.9      2195.85
        wave_hosp: 9 & rel: 0    3030.84      704.631  4.30    $pv   1649.15     4412.53
        wave_hosp: 9 & rel: 1     106.838     652.767  0.16    0.8700  -1173.16     1386.83
        wave_hosp: 10 & rel: -3   591.046    1273.08   0.46    0.6425  -1905.3      3087.39
        wave_hosp: 10 & rel: -2   410.581    1030.4    0.40    0.6903  -1609.9      2431.06
        wave_hosp: 10 & rel: 0   3091.51      998.667  3.10    0.0020   1133.25     5049.77
        ───────────────────────────────────────────────────────────────────────────────────"""

    r = @did(Reg, data=hrs, dynamic(:wave, -1), notyettreated(11),
        vce=Vcov.cluster(:hhidpn), yterm=term(:oop_spend), treatname=:wave_hosp,
        treatintterms=(), xterms=(fe(:wave)+fe(:hhidpn)), solvelsweights=true)
    # Compare estimates with Stata results from Sun and Abraham (2020)
    a = agg(r, :rel)
    @test coef(a, "rel: -3") ≈ 591.04639 atol=1e-5
    @test coef(a, "rel: -2") ≈ 352.63929 atol=1e-5
    @test coef(a, "rel: 0") ≈ 2960.0448 atol=1e-4
    @test coef(a, "rel: 1") ≈ 529.76686 atol=1e-5
    @test coef(a, "rel: 2") ≈ 800.10647 atol=1e-5

    @test a.cellweights == a.cellcounts
    @test a.cellcounts == [163, 339, 591, 428, 252]
    @test all(i->a.coef[i]≈sum(a.lsweights[:,i].*r.ycellmeans), 1:ntreatcoef(a))

    a1 = agg(r, (:rel,), subset=:rel=>isodd)
    @test length(coef(a1)) == 2
    @test coef(a1, "rel: -3") == coef(a, "rel: -3")
    @test coef(a1, "rel: 1") == coef(a, "rel: 1")
    @test sprint(show, a1) === """
        ───────────────────────────────────────────────────────────────────
                 Estimate  Std. Error     t  Pr(>|t|)  Lower 95%  Upper 95%
        ───────────────────────────────────────────────────────────────────
        rel: -3   591.046    1273.08   0.46    0.6425  -1905.3      3087.39
        rel: 1    529.767     586.831  0.90    0.3667   -620.935    1680.47
        ───────────────────────────────────────────────────────────────────"""

    a1 = agg(r, [:rel], bys=:rel=>isodd)
    @test length(coef(a1)) == 2
    @test coef(a1, "rel: false") ≈ sum(coef(a, "rel: $r") for r in ["-2", "0", "2"])
    @test coef(a1, "rel: true") ≈ sum(coef(a, "rel: $r") for r in ["-3", "1"])
end

@testset "@specset" begin
    hrs = exampledata("hrs")
    # The first two specs are identical hence no repetition of steps should occur
    # The third spec should only share the first three steps with the others
    r = @specset [verbose] begin
        @did(Reg, dynamic(:wave, -1), notyettreated(11), data=hrs,
            yterm=term(:oop_spend), treatname=:wave_hosp, treatintterms=(),
            xterms=(fe(:wave)+fe(:hhidpn)))
        @did(Reg, dynamic(:wave, -1), notyettreated(11), data=hrs,
            yterm=term(:oop_spend), treatname=:wave_hosp, treatintterms=[],
            xterms=[fe(:hhidpn), fe(:wave)])
        @did(Reg, dynamic(:wave, -1), nevertreated(11), data=hrs,
            yterm=term(:oop_spend), treatname=:wave_hosp, treatintterms=(),
            xterms=(fe(:wave)+fe(:hhidpn)))
    end
    @test r[1] == didspec(Reg, dynamic(:wave, -1), notyettreated(11), data=hrs,
        yterm=term(:oop_spend), treatname=:wave_hosp, treatintterms=(),
        xterms=TermSet(fe(:wave), fe(:hhidpn)))()
end
