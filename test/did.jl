@testset "RegressionBasedDID" begin
    hrs = exampledata("hrs")
    r = @did(Reg, data=hrs, dynamic(:wave, -1), notyettreated([11]),
        vce=Vcov.cluster(:hhidpn), yterm=term(:oop_spend), treatname=:wave_hosp,
        treatintterms=(), xterms=(fe(:wave)+fe(:hhidpn)))
    @test coef(r, "rel: -3 & wave_hosp: 10") ≈ 591.04639 atol=1e-5
    @test coef(r, "rel: -2 & wave_hosp: 9") ≈ 298.97735 atol=1e-5
    @test coef(r, "rel: -2 & wave_hosp: 10") ≈ 410.58102 atol=1e-5
    @test coef(r, "rel: 0 & wave_hosp: 8") ≈ 2825.5659 atol=1e-4
    @test coef(r, "rel: 0 & wave_hosp: 9") ≈ 3030.8408 atol=1e-4
    @test coef(r, "rel: 0 & wave_hosp: 10") ≈ 3091.5084 atol=1e-4
    @test coef(r, "rel: 1 & wave_hosp: 8") ≈ 825.14585 atol=1e-5
    @test coef(r, "rel: 1 & wave_hosp: 9") ≈ 106.83785 atol=1e-5
    @test coef(r, "rel: 2 & wave_hosp: 8") ≈ 800.10647 atol=1e-5
    @test nobs(r) == 2624
    
    @test sprint(show, r) == "Regression-based DID result"
    @test sprint(show, MIME("text/plain"), r) == """
        ──────────────────────────────────────────────────────────────────────
        Summary of results: Regression-based DID
        ──────────────────────────────────────────────────────────────────────
        Number of obs:               2624    Degrees of freedom:           670
        F-statistic:                 4.81    p-value:                    <1e-5
        ──────────────────────────────────────────────────────────────────────
        Cohort-interacted sharp dynamic specification
        ──────────────────────────────────────────────────────────────────────
        Number of cohorts:              3    Interactions within cohorts:    0
        Relative time periods:          5    Excluded periods:              -1
        ──────────────────────────────────────────────────────────────────────
        Fixed effects: fe_wave fe_hhidpn
        ──────────────────────────────────────────────────────────────────────
        Converged:                   true    Singletons dropped:             0
        ──────────────────────────────────────────────────────────────────────"""

    r = @did(Reg, data=hrs, dynamic(:wave, -1), notyettreated([11]),
        vce=Vcov.cluster(:hhidpn), yterm=term(:oop_spend), treatname=:wave_hosp,
        treatintterms=(), cohortinteracted=false)
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
end
