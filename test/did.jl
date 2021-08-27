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
    @test treatment(r) == dynamic(:wave, -1)
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

    @test has_lsweights(r)
    @test r.cellweights == r.cellcounts
    @test r.cellcounts == repeat([252, 176, 163, 65], inner=4)
    @test all(i->r.coef[i] ≈ sum(r.lsweights[:,i].*r.cellymeans), 1:ntreatcoef(r))

    @test has_fe(r)

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

    df = DataFrame(hrs)
    df.wave = settime(Date.(hrs.wave), Year(1))
    df.wave_hosp = settime(Date.(hrs.wave_hosp), Year(1), start=Date(7))
    r1 = @did(Reg, data=df, dynamic(:wave, -1), notyettreated(Date(11)),
        vce=Vcov.cluster(:hhidpn), yterm=term(:oop_spend), treatname=:wave_hosp,
        treatintterms=(), xterms=(fe(:wave)+fe(:hhidpn)), solvelsweights=true)
    @test coef(r1) ≈ coef(r)
    @test r1.coefnames[1] == "wave_hosp: 0008-01-01 & rel: 0"

    rot = ifelse.(isodd.(hrs.hhidpn), 1, 2)
    df.wave = settime(Date.(hrs.wave), Year(1), rotation=rot)
    df.wave_hosp = settime(Date.(hrs.wave_hosp), Year(1), start=Date(7), rotation=rot)
    e = rotatingtime((1,2), Date(11))
    r2 = @did(Reg, data=df, dynamic(:wave, -1), notyettreated(e),
        vce=Vcov.cluster(:hhidpn), yterm=term(:oop_spend), treatname=:wave_hosp,
        treatintterms=(), xterms=(fe(:wave)+fe(:hhidpn)), solvelsweights=true)
    @test length(coef(r2)) == 18
    @test coef(r2)[1] ≈ 3790.7218412450593
    @test r2.coefnames[1] == "wave_hosp: 1_0008-01-01 & rel: 0"

    r = @did(Reg, data=hrs, dynamic(:wave, -1), notyettreated([11]),
        vce=Vcov.cluster(:hhidpn), yterm=term(:oop_spend), treatname=:wave_hosp,
        treatintterms=(), cohortinteracted=false, lswtnames=(:wave_hosp, :wave))
    @test all(i->r.coef[i] ≈ sum(r.lsweights[:,i].*r.cellymeans), 1:ntreatcoef(r))

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

    r0 = @did(Reg, data=hrs, dynamic(:wave, -1), unspecifiedpr(),
        vce=Vcov.cluster(:hhidpn), yterm=term(:oop_spend), treatname=:wave_hosp,
        treatintterms=(), xterms=(fe(:wave),),
        cohortinteracted=false, solvelsweights=true)
    # Compare estimates with Stata
    # gen rel = wave - wave_hosp
    # gen irel?? = rel==??
    # reghdfe oop_spend irel*, a(wave) cluster(hhidpn)
    @test coef(r0) ≈ [-1029.0482, 245.20926, 188.59266, 3063.2707,
        1060.5317, 1152.3315, 1986.7811] atol=1e-4
    @test diag(vcov(r0)) ≈ [764612.86, 626165.68, 236556.13, 163459.83,
        130471.28, 294368.49, 677821.36] atol=1e0
    pv = VERSION < v"1.6.0" ? " <1e-8" : "<1e-08"
    @test sprint(show, MIME("text/plain"), r0) == """
        ──────────────────────────────────────────────────────────────────────
        Summary of results: Regression-based DID
        ──────────────────────────────────────────────────────────────────────
        Number of obs:               3280    Degrees of freedom:            12
        F-statistic:                 9.12    p-value:                   $pv
        ──────────────────────────────────────────────────────────────────────
        Sharp dynamic specification
        ──────────────────────────────────────────────────────────────────────
        Relative time periods:          7    Excluded periods:              -1
        ──────────────────────────────────────────────────────────────────────
        Fixed effects: fe_wave
        ──────────────────────────────────────────────────────────────────────
        Converged:                   true    Singletons dropped:             0
        ──────────────────────────────────────────────────────────────────────"""

    sr = view(r, 1:3)
    @test coef(sr)[1] == r.coef[1]
    @test vcov(sr)[1] == r.vcov[1]
    @test parent(sr) === r

    tr = rescale(r, fill(2, 5), 1:5)
    @test coef(tr)[1] ≈ 2 * coef(sr)[1]
    @test vcov(tr)[1] ≈ 4 * vcov(sr)[1]
end

@testset "AggregatedRegDIDResult" begin
    hrs = exampledata("hrs")
    r = @did(Reg, data=hrs, dynamic(:wave, -1), notyettreated(11),
        vce=Vcov.cluster(:hhidpn), yterm=term(:oop_spend), treatname=:wave_hosp,
        treatintterms=(), xterms=(fe(:wave)+fe(:hhidpn)))
    a = agg(r)
    @test coef(a) == coef(r)
    @test vcov(a) == vcov(r)
    @test vce(a) == vce(r)
    @test treatment(a) == dynamic(:wave, -1)
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

    @test !has_lsweights(a)

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

    @test has_lsweights(a)
    @test a.treatweights == a.treatcounts
    @test a.treatcounts == [163, 339, 591, 428, 252]
    @test all(i->a.coef[i] ≈ sum(a.lsweights[:,i].*r.cellymeans), 1:ntreatcoef(a))

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

    a2 = agg(r, :rel, bys=:rel=>isodd, subset=:rel=>isodd)
    @test coef(a2) == coef(a1, 2:2)

    @test_throws ArgumentError agg(r, subset=:rel=>x->x>10)
end

@testset "@specset" begin
    hrs = exampledata("hrs")
    # The first two specs are identical hence no repetition of steps should occur
    # The third spec should share all the steps until SolveLeastSquares
    # The fourth and fifth specs should not add tasks for MakeFEs and MakeYXCols
    # The sixth spec should not add any task for MakeFEs
    r = @specset [verbose] data=hrs yterm=term(:oop_spend) treatname=:wave_hosp begin
        @did(Reg, dynamic(:wave, -1), notyettreated(11),
            xterms=(fe(:wave)+fe(:hhidpn)))
        @did(Reg, dynamic(:wave, -1), notyettreated(11),
            xterms=[fe(:hhidpn), fe(:wave)])
        @did(Reg, dynamic(:wave, -2:-1), notyettreated(11),
            xterms=[fe(:hhidpn), fe(:wave)])
        @did(Reg, dynamic(:wave, -1), notyettreated(11),
            xterms=[term(:male), fe(:hhidpn), fe(:wave)])
        @did(Reg, dynamic(:wave, -1), notyettreated(11),
            treatintterms=TermSet(:male), xterms=[fe(:hhidpn), fe(:wave)])
        @did(Reg, dynamic(:wave, -1), nevertreated(11),
            xterms=(fe(:wave)+fe(:hhidpn)))
    end
    # Results might differ due to yxterms that include terms from other specs
    @test r[2][4] == didspec(Reg, dynamic(:wave, -1), notyettreated(11), data=hrs,
        yterm=term(:oop_spend), treatname=:wave_hosp, treatintterms=(),
        xterms=TermSet(term(:male), fe(:wave), fe(:hhidpn)))()

    r = @specset data=hrs yterm=term(:oop_spend) treatname=:wave_hosp begin
        @did(Reg, dynamic(:wave, -2:-1), nevertreated(11),
            xterms=(fe(:wave)+fe(:hhidpn)))
        @did(Reg, dynamic(:wave, -1), nevertreated(11),
            xterms=[fe(:hhidpn), fe(:wave)])
    end
    @test r[2][1] == @did(Reg, data=hrs, yterm=term(:oop_spend), treatname=:wave_hosp,
        dynamic(:wave, -2:-1), nevertreated(11), xterms=(fe(:wave)+fe(:hhidpn)))
end

@testset "contrast" begin
    hrs = exampledata("hrs")
    r1 = @did(Reg, data=hrs, dynamic(:wave, -1), notyettreated(11),
        vce=Vcov.cluster(:hhidpn), yterm=term(:oop_spend), treatname=:wave_hosp,
        treatintterms=(), xterms=(fe(:wave)+fe(:hhidpn)), solvelsweights=true)
    r2 = agg(r1, :rel)
    c1 = contrast(r1)
    @test size(c1) == (16, 10)
    @test parent(c1) == [r1]
    c2 = contrast(r1, r2)
    @test size(c2) == (16, 15)
    @test c2[1] == r1.cellymeans[1]
    @test c2[1,2] == r1.lsweights[1]
    @test IndexStyle(typeof(c2)) == IndexLinear()
    
    @test c2.r == r1.lsweights.r == r2.lsweights.r
    @test c2.c.name[1] == "cellymeans"
    @test c2.c.name[2] == r1.coefnames[c2.c.icoef[2]]
    @test c2.c.iresult == [0, (1 for i in 1:9)..., (2 for i in 1:5)...]
    @test c2.c.icoef == [0, 1:9..., 1:5...]
    @test parent(c2)[1] === r1
    @test parent(c2)[2] === r2

    @test c1.r !== r1.lsweights.r
    sort!(c1, rev=true)
    @test c1.r == sort(r1.lsweights.r, rev=true)

    @test view(c1, :) == c1
    v = view(c1, :wave=>x->x==10)
    @test v.m == c1.m[c1.r.wave.==10,:]
    v = view(c1, 1:10)
    @test v.m == c1.m[1:10,:]
    @test v.r == view(c1.r, 1:10)
    v = view(c1, [:wave=>x->x==10, :wave_hosp=>x->x==10])
    @test v.m == c1.m[(c1.r.wave.==10).&(c1.r.wave_hosp.==10),:]
    @test v.r == view(c1.r, (c1.r.wave.==10).&(c1.r.wave_hosp.==10))

    c3 = contrast(r1, r2, subset=:wave=>7, coefs=1=>(:wave_hosp,2)=>(x,y)->x+y==8)
    @test size(c3) == (4, 8)
    @test parent(c3)[1] === r1
    @test c3.c.name[2] == "wave_hosp: 8 & rel: 0"
    @test c3.c.name[3] == "wave_hosp: 10 & rel: -2"
    @test c3.c.iresult == [0, (1 for i in 1:2)..., (2 for i in 1:5)...]
    @test c3.c.icoef == [0, 1, 8, 1:5...]
    @test all(c3.r.wave.==7)
    ri = r1.lsweights.r.wave.==7
    @test c3[:,1] == r1.cellymeans[ri]
    @test c3[:,2:end] == c2[ri,[2,9,11:15...]]

    c4 = contrast(r1, r2, subset=1:3, coefs=(1=>1:2, 2=>:))
    @test size(c4) == (3, 8)
    @test c4.c.iresult == [0, (1 for i in 1:2)..., (2 for i in 1:5)...]
    @test c4.c.icoef == [0:2..., 1:5...]
    @test c4.r == view(r1.lsweights.r, 1:3)
    @test c4[:,2:end] == c2[1:3,[2,3,11:15...]]
end

@testset "post!" begin
    hrs = exampledata("hrs")
    r1 = @did(Reg, data=hrs, dynamic(:wave, -1), notyettreated(11),
        vce=Vcov.cluster(:hhidpn), yterm=term(:oop_spend), treatname=:wave_hosp,
        treatintterms=(), xterms=(fe(:wave)+fe(:hhidpn)), solvelsweights=true)
    c1 = contrast(r1)
    gl = Dict{String,Any}()
    gr = Dict{String,Any}()
    gd = Dict{String,Any}()
    post!(gl, gr, gd, StataPostHDF(), c1, model="m")
    @test gl["model"] == "m"
    @test gl["depvar"] == "l_2"
    @test gl["b"] == r1.lsweights[:,1]
    @test gr["depvar"] == "r_3"
    @test gr["b"] == r1.lsweights[:,2]
    @test gd["depvar"] == "d_2_3"
    @test gd["b"] == (r1.lsweights[:,1].-r1.lsweights[:,2]).*r1.cellymeans
    cnames = string.(1:16)
    @test all(g->g["coefnames"]==cnames, (gl, gr, gd))
    @test all(g->!haskey(g, "at"), (gl, gr, gd))

    gl = Dict{String,Any}()
    gr = Dict{String,Any}()
    gd = Dict{String,Any}()
    post!(gl, gr, gd, StataPostHDF(), c1,
        lefttag="x", righttag="y", colnames=16:-1:1, at=1:16)
    @test gl["depvar"] == "l_x"
    @test gl["b"] == r1.lsweights[:,1]
    @test gr["depvar"] == "r_y"
    @test gr["b"] == r1.lsweights[:,2]
    cnames = string.(16:-1:1)
    @test all(g->g["coefnames"]==cnames, (gl, gr, gd))
    @test all(g->g["at"]==1:16, (gl, gr, gd))

    gl = Dict{String,Any}()
    gr = Dict{String,Any}()
    gd = Dict{String,Any}()
    post!(gl, gr, gd, StataPostHDF(), c1, eqnames=1:16)
    cnames = [string(i,":",i) for i in 1:16]
    @test all(g->g["coefnames"]==cnames, (gl, gr, gd))
    
    gl = Dict{String,Any}()
    gr = Dict{String,Any}()
    gd = Dict{String,Any}()
    post!(gl, gr, gd, StataPostHDF(), c1, eqnames=1:16, colnames=16:-1:1)
    cnames = [string(i,":",17-i) for i in 1:16]
    @test all(g->g["coefnames"]==cnames, (gl, gr, gd))

    gl = Dict{String,Any}()
    gr = Dict{String,Any}()
    gd = Dict{String,Any}()
    @test_throws ArgumentError post!(gl, gr, gd, StataPostHDF(), c1, eqnames=1:2)
    @test_throws ArgumentError post!(gl, gr, gd, StataPostHDF(), c1, colnames=1:2)
    @test_throws ArgumentError post!(gl, gr, gd, StataPostHDF(), c1, at=1:2)
end
