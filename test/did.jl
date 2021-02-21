@testset "RegressionBasedDID" begin
    hrs = exampledata("hrs")
    r = @did(Reg, data=hrs, dynamic(:wave, -1), notyettreated([11]), vce=Vcov.cluster(:hhidpn),
        yterm=term(:oop_spend), treatname=:wave_hosp, treatintterms=(),
        xterms=(fe(:wave)+fe(:hhidpn)))
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
    
end
