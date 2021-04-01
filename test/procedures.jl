@testset "CheckVcov" begin
    hrs = exampledata("hrs")
    nt = (data=hrs, esample=trues(size(hrs,1)), vce=Vcov.robust())
    @test checkvcov!(nt...) == NamedTuple()
    nt = merge(nt, (vce=Vcov.cluster(:hhidpn),))
    @test checkvcov!(nt...) == (esample=trues(size(hrs,1)),)

    @test CheckVcov()((data=hrs, esample=trues(size(hrs,1)))) ==
        (data=hrs, esample=trues(size(hrs,1)))
end

@testset "CheckFEs" begin
    hrs = exampledata("hrs")
    nt = (data=hrs, esample=trues(size(hrs,1)), xterms=TermSet(term(:white)), drop_singletons=true)
    @test checkfes!(nt...) == (xterms=TermSet(term(:white)),
        esample=trues(size(hrs,1)), fes=FixedEffect[], fenames=Symbol[],
        has_fe_intercept=false, nsingle=0)
    nt = merge(nt, (xterms=TermSet(fe(:hhidpn)),))
    @test checkfes!(nt...) == (xterms=TermSet(InterceptTerm{false}()),
        esample=trues(size(hrs,1)), fes=[FixedEffect(hrs.hhidpn)], fenames=[:fe_hhidpn],
        has_fe_intercept=true, nsingle=0)
    
    df = DataFrame(hrs)
    df = df[(df.wave.==7).|((df.wave.==8).&(df.wave_hosp.==8)), :]
    N = size(df, 1)
    nt = merge(nt, (data=df, esample=trues(N), xterms=TermSet(fe(:hhidpn))))
    kept = df.wave_hosp.==8
    @test checkfes!(nt...) == (xterms=TermSet(InterceptTerm{false}()), esample=kept,
        fes=[FixedEffect(df.hhidpn)], fenames=[:fe_hhidpn], has_fe_intercept=true,
        nsingle=N-sum(kept))

    df = df[df.wave.==7, :]
    N = size(df, 1)
    nt = merge(nt, (data=df, esample=trues(N), xterms=TermSet(fe(:hhidpn))))
    @test_throws ErrorException checkfes!(nt...)

    @test_throws ErrorException CheckFEs()(nt)
    nt = merge(nt, (drop_singletons=false, esample=trues(N),
        xterms=TermSet(fe(:hhidpn))))
    @test CheckFEs()(nt) == merge(nt, (xterms=TermSet(InterceptTerm{false}()),
        fes=[FixedEffect(df.hhidpn)], fenames=[:fe_hhidpn], has_fe_intercept=true, nsingle=0))
end

@testset "MakeFESolver" begin
    hrs = exampledata("hrs")
    N = size(hrs, 1)
    fes = FixedEffect[FixedEffect(hrs.hhidpn)]
    fenames = [:fe_hhidpn]
    nt = (fes=fes, weights=uweights(N), esample=trues(N), default(MakeFESolver())...)
    ret = makefesolver!(nt...)
    @test ret.feM isa FixedEffects.FixedEffectSolverCPU{Float64}
    nt = merge(nt, (fes=FixedEffect[],))
    @test makefesolver!(nt...) == (feM=nothing, fes=FixedEffect[])
    @test MakeFESolver()(nt) == merge(nt, (feM=nothing,))
end

@testset "MakeYXCols" begin
    hrs = exampledata("hrs")
    N = size(hrs, 1)
    t1 = InterceptTerm{true}()
    nt = (data=hrs, weights=uweights(N), esample=trues(N), feM=nothing,
        has_fe_intercept=false, default(MakeYXCols())...)
    ret = makeyxcols(nt..., TermSet(term(:oop_spend), term(1)))
    @test ret.yxterms[term(:oop_spend)] isa ContinuousTerm
    @test ret.yxcols == Dict(ret.yxterms[term(:oop_spend)]=>hrs.oop_spend,
        t1=>ones(N))
    
    @test ret.nfeiterations === nothing
    @test ret.feconverged === nothing

    # Verify that an intercept will be added if not having one
    ret1 = makeyxcols(nt..., TermSet(term(:oop_spend)))
    @test ret1 == ret
    ret1 = makeyxcols(nt..., TermSet(term(:oop_spend), term(0)))
    @test collect(keys(ret1.yxterms)) == [term(:oop_spend)]
    @test ret1.yxcols == ret.yxcols

    wt = Weights(hrs.rwthh)
    nt = merge(nt, (weights=wt,))
    ret = makeyxcols(nt..., TermSet(term(:oop_spend), term(:riearnsemp), term(:male)))
    @test ret.yxcols == Dict(ret.yxterms[term(:oop_spend)]=>hrs.oop_spend.*sqrt.(wt),
        ret.yxterms[term(:riearnsemp)]=>hrs.riearnsemp.*sqrt.(wt),
        ret.yxterms[term(:male)]=>reshape(hrs.male.*sqrt.(wt), N),
        t1=>reshape(sqrt.(wt), N))

    df = DataFrame(hrs)
    df.riearnsemp[1] = NaN
    nt = merge(nt, (data=df,))
    @test_throws ErrorException makeyxcols(nt..., TermSet(term(:riearnsemp), term(1)))
    df.spouse = convert(Vector{Float64}, df.spouse)
    df.spouse[1] = Inf
    @test_throws ErrorException makeyxcols(nt..., TermSet(term(:oop_spend), term(:spouse)))

    df = DataFrame(hrs)
    x = randn(N)
    df.x = x
    wt = uweights(N)
    fes = [FixedEffect(df.hhidpn)]
    feM = AbstractFixedEffectSolver{Float64}(fes, wt, Val{:cpu}, Threads.nthreads())
    nt = merge(nt, (data=df, weights=wt, feM=feM, has_fe_intercept=true))
    ret = makeyxcols(nt..., TermSet(term(:oop_spend), InterceptTerm{false}(), term(:x)))
    resids = reshape(copy(df.oop_spend), N, 1)
    _feresiduals!(resids, feM, 1e-8, 10000)
    resids .*= sqrt.(wt)
    @test ret.yxcols[ret.yxterms[term(:oop_spend)]] == reshape(resids, N)
    # Verify input data are not modified
    @test df.oop_spend == hrs.oop_spend
    @test df.x == x

    df = DataFrame(hrs)
    esample = df.rwthh.> 0
    N = sum(esample)
    wt = Weights(hrs.rwthh[esample])
    fes = [FixedEffect(df.hhidpn[esample])]
    feM = AbstractFixedEffectSolver{Float64}(fes, wt, Val{:cpu}, Threads.nthreads())
    nt = merge(nt, (data=df, esample=esample, weights=wt, feM=feM, has_fe_intercept=true))
    ret = makeyxcols(nt..., TermSet(term(:oop_spend), InterceptTerm{false}()))
    resids = reshape(df.oop_spend[esample], N, 1)
    _feresiduals!(resids, feM, 1e-8, 10000)
    resids .*= sqrt.(wt)
    @test ret.yxcols == Dict(ret.yxterms[term(:oop_spend)]=>reshape(resids, N))
    @test ret.nfeiterations isa Int
    @test ret.feconverged
    # Verify input data are not modified
    @test df.oop_spend == hrs.oop_spend

    allntargs = NamedTuple[(yterm=term(:oop_spend), xterms=TermSet())]
    @test combinedargs(MakeYXCols(), allntargs) == (TermSet(term(:oop_spend)),)
    push!(allntargs, allntargs[1])
    @test combinedargs(MakeYXCols(), allntargs) == (TermSet(term(:oop_spend)),)
    push!(allntargs, (yterm=term(:riearnsemp),
        xterms=TermSet(InterceptTerm{false}())))
    @test combinedargs(MakeYXCols(), allntargs) ==
        (TermSet(term(:oop_spend), term(:riearnsemp), InterceptTerm{false}()),)
    push!(allntargs, (yterm=term(:riearnsemp), xterms=TermSet(term(:male))))
    @test combinedargs(MakeYXCols(), allntargs) ==
        (TermSet(term(:oop_spend), term(:riearnsemp), InterceptTerm{false}(), term(:male)),)
    
    nt = merge(nt, (data=df, yterm=term(:oop_spend), xterms=TermSet(InterceptTerm{false}())))
    @test MakeYXCols()(nt) == merge(nt, ret)
end

@testset "MakeTreatCols" begin
    hrs = exampledata("hrs")
    N = size(hrs, 1)
    tr = dynamic(:wave, -1)
    pr = nevertreated(11)
    nt = (data=hrs, treatname=:wave_hosp, treatintterms=TermSet(), feM=nothing,
        weights=uweights(N), esample=trues(N), default(MakeTreatCols())...)
    ret = maketreatcols(nt..., typeof(tr), tr.time, IdDict(-1=>1), IdDict{TimeType,Int}(11=>1))
    @test size(ret.cells) == (20, 2)
    @test length(ret.rows) == 20
    @test size(ret.treatcells) == (12, 2)
    @test length(ret.treatcols) == length(ret.treatrows) == 12
    @test length(ret.cellweights) == length(ret.cellcounts) == length(ret.treatrows)
    @test ret.cells.wave_hosp == repeat(8:11, inner=5)
    @test ret.cells.wave == repeat(7:11, 4)
    @test ret.rows[end] == findall((hrs.wave_hosp.==11).&(hrs.wave.==11))
    @test ret.treatcells.wave_hosp == repeat(8:10, inner=4)
    rel = ret.cells.wave .- ret.cells.wave_hosp
    @test ret.treatcells.rel == rel[(rel.!=-1).&(ret.cells.wave_hosp.!=11)]
    @test ret.treatrows[1] == findall((hrs.wave_hosp.==8).&(hrs.wave.==8))
    col = convert(Vector{Float64}, (hrs.wave_hosp.==8).&(hrs.wave.==8))
    @test ret.treatcols[1] == col
    @test ret.cellweights == ret.cellcounts
    w = ret.cellweights
    @test all(w[ret.treatcells.wave_hosp.==8].==252)
    @test all(w[ret.treatcells.wave_hosp.==9].==176)
    @test all(w[ret.treatcells.wave_hosp.==10].==163)

    nt = merge(nt, (treatintterms=TermSet(term(:male)),))
    ret1 = maketreatcols(nt..., typeof(tr), tr.time, IdDict(-1=>1), IdDict{TimeType,Int}(11=>1))
    @test size(ret1.cells) == (40, 3)
    @test length(ret1.rows) == 40
    @test size(ret1.treatcells) == (24, 3)
    @test length(ret1.treatcols) == length(ret1.treatrows) == 24
    @test length(ret1.cellweights) == length(ret1.cellcounts) == length(ret1.treatrows)
    @test ret1.cells.wave_hosp == repeat(8:11, inner=10)
    @test ret1.cells.wave == repeat(repeat(7:11, inner=2), 4)
    @test ret1.cells.male == repeat(0:1, 20)
    @test ret1.rows[end] == findall((hrs.wave_hosp.==11).&(hrs.wave.==11).&(hrs.male.==1))
    @test ret1.treatcells.wave_hosp == repeat(8:10, inner=8)
    rel = ret1.cells.wave .- ret1.cells.wave_hosp
    @test ret1.treatcells.rel == rel[(rel.!=-1).&(ret1.cells.wave_hosp.!=11)]
    @test ret1.treatrows[1] == findall((hrs.wave_hosp.==8).&(hrs.wave.==8).&(hrs.male.==0))
    col1 = convert(Vector{Float64}, (hrs.wave_hosp.==8).&(hrs.wave.==8).&(hrs.male.==0))
    @test ret1.treatcols[1] == col1
    @test ret1.cellweights == ret1.cellcounts

    nt = merge(nt, (cohortinteracted=false, treatintterms=TermSet()))
    ret2 = maketreatcols(nt..., typeof(tr), tr.time, IdDict(-1=>1), IdDict{TimeType,Int}(11=>1))
    @test ret2.cells[1] == ret.cells[1]
    @test ret2.cells[2] == ret.cells[2]
    @test ret2.rows == ret.rows
    @test size(ret2.treatcells) == (6, 1)
    @test length(ret2.treatcols) == length(ret2.treatrows) == 6
    @test length(ret2.cellweights) == length(ret2.cellcounts) == length(ret2.treatrows)
    @test ret2.treatcells.rel == [-3, -2, 0, 1, 2, 3]
    @test ret2.treatrows[1] == findall((hrs.wave.-hrs.wave_hosp.==-3).&(hrs.wave_hosp.!=11))
    col2 = convert(Vector{Float64}, (hrs.wave.-hrs.wave_hosp.==-3).&(hrs.wave_hosp.!=11))
    @test ret2.treatcols[1] == col2
    @test ret2.cellweights == ret2.cellcounts

    nt = merge(nt, (treatintterms=TermSet(term(:male)),))
    ret3 = maketreatcols(nt..., typeof(tr), tr.time, IdDict(-1=>1), IdDict{TimeType,Int}(11=>1))
    @test ret3.cells[1] == ret1.cells[1]
    @test ret3.cells[2] == ret1.cells[2]
    @test ret3.cells[3] == ret1.cells[3]
    @test ret3.rows == ret1.rows
    @test size(ret3.treatcells) == (12, 2)
    @test length(ret3.treatcols) == length(ret3.treatrows) == 12
    @test length(ret3.cellweights) == length(ret3.cellcounts) == length(ret3.treatrows)
    @test ret3.treatcells.rel == repeat([-3, -2, 0, 1, 2, 3], inner=2)
    @test ret3.treatcells.male == repeat(0:1, 6)
    @test ret3.treatrows[1] ==
        findall((hrs.wave.-hrs.wave_hosp.==-3).&(hrs.wave_hosp.!=11).&(hrs.male.==0))

    df = DataFrame(hrs)
    esample = df.rwthh.> 0
    N = sum(esample)
    wt = Weights(hrs.rwthh[esample])
    fes = [FixedEffect(df.hhidpn[esample])]
    feM = AbstractFixedEffectSolver{Float64}(fes, wt, Val{:cpu}, Threads.nthreads())
    nt = merge(nt, (data=df, feM=feM, weights=wt, esample=esample,
        treatintterms=TermSet(), cohortinteracted=true))
    ret = maketreatcols(nt..., typeof(tr), tr.time, IdDict(-1=>1), IdDict{TimeType,Int}(11=>1))
    col = reshape(col[esample], N, 1)
    defaults = (default(MakeTreatCols())...,)
    _feresiduals!(col, feM, defaults[2:3]...)
    @test ret.treatcols[1] == (col.*sqrt.(wt))[:]
    @test ret.cellcounts == [252, 252, 252, 251, 176, 176, 176, 175, 162, 160, 163, 162]
    @test ret.cellweights[1] == 1776173

    allntargs = NamedTuple[(tr=tr, pr=pr)]
    @test combinedargs(MakeTreatCols(), allntargs) ==
        (IdDict(-1=>1), IdDict{TimeType,Int}(11=>1))
    push!(allntargs, allntargs[1])
    @test combinedargs(MakeTreatCols(), allntargs) ==
        (IdDict(-1=>2), IdDict{TimeType,Int}(11=>2))
    push!(allntargs, (tr=dynamic(:wave, [-1,-2]), pr=nevertreated(10:11)))
    @test combinedargs(MakeTreatCols(), allntargs) ==
        (IdDict(-1=>3), IdDict{TimeType,Int}(11=>3))
    push!(allntargs, (tr=dynamic(:wave, [-3]), pr=nevertreated(10)))
    @test combinedargs(MakeTreatCols(), allntargs) ==
        (IdDict{Int,Int}(), IdDict{TimeType,Int}())

    nt = merge(nt, (tr=tr, pr=pr))
    @test MakeTreatCols()(nt) == merge(nt, (cells=ret.cells, rows=ret.rows,
        treatcells=ret.treatcells, treatrows=ret.treatrows, treatcols=ret.treatcols,
        cellweights=ret.cellweights, cellcounts=ret.cellcounts))
end

@testset "SolveLeastSquares" begin
    hrs = exampledata("hrs")
    N = size(hrs, 1)
    df = DataFrame(hrs)
    df.t2 = fill(2.0, N)
    t1 = InterceptTerm{true}()
    t0 = InterceptTerm{false}()
    tr = dynamic(:wave, -1)
    pr = nevertreated(11)
    yxterms = Dict([x=>apply_schema(x, schema(x, df), StatisticalModel)
        for x in (term(:oop_spend), t1, term(:t2), t0, term(:male), term(:spouse))])
    yxcols0 = Dict(yxterms[term(:oop_spend)]=>hrs.oop_spend, t1=>ones(N, 1),
        yxterms[term(:male)]=>hrs.male, yxterms[term(:spouse)]=>hrs.spouse)
    col0 = convert(Vector{Float64}, (hrs.wave_hosp.==10).&(hrs.wave.==10))
    col1 = convert(Vector{Float64}, (hrs.wave_hosp.==10).&(hrs.wave.==11))
    treatcells0 = VecColumnTable((rel=[0, 1], wave_hosp=[10, 10]))
    treatcols0 = [col0, col1]
    nt = (tr=tr, pr=pr, yterm=term(:oop_spend), xterms=TermSet(term(1)), yxterms=yxterms,
        yxcols=yxcols0, treatcells=treatcells0, treatcols=treatcols0,
        cohortinteracted=true, has_fe_intercept=false)
    ret = solveleastsquares!(nt...)
    # Compare estimates with Stata
    # gen col0 = wave_hosp==10 & wave==10
    # gen col1 = wave_hosp==10 & wave==11
    # reg oop_spend col0 col1
    @test ret.coef[1] ≈ 2862.4141 atol=1e-4
    @test ret.coef[2] ≈ 490.44869 atol=1e-4
    @test ret.coef[3] ≈ 3353.6565 atol=1e-4
    @test ret.treatcells.wave_hosp == [10, 10]
    @test ret.treatcells.rel == [0, 1]
    @test ret.xterms == AbstractTerm[t1]
    @test ret.basecols == trues(3)

    # Verify that an intercept will only be added when needed
    nt1 = merge(nt, (xterms=TermSet(),))
    ret1 = solveleastsquares!(nt1...)
    @test ret1 == ret
    nt1 = merge(nt, (xterms=TermSet(term(0)),))
    ret1 = solveleastsquares!(nt1...)
    @test ret1.xterms == AbstractTerm[]
    @test size(ret1.X, 2) == 2
    nt1 = merge(nt, (xterms=TermSet((term(:spouse), term(:male))),))
    ret1 = solveleastsquares!(nt1...)
    @test ret1.xterms == AbstractTerm[yxterms[term(:male)], yxterms[term(:spouse)],
        InterceptTerm{true}()]

    # Test colliner xterms are handled
    yxcols1 = Dict(yxterms[term(:oop_spend)]=>hrs.oop_spend, t1=>ones(N),
        yxterms[term(:t2)]=>df.t2)
    nt1 = merge(nt, (xterms=TermSet(term(1), term(:t2)), yxcols=yxcols1))
    ret1 = solveleastsquares!(nt1...)
    @test ret1.coef[1:2] == ret.coef[1:2]
    @test sum(ret1.basecols) == 3

    treatcells1 = VecColumnTable((rel=[0, 1, 1, 1], wave_hosp=[10, 10, 0, 1]))
    treatcols1 = push!(copy(treatcols0), ones(N), ones(N))
    # basecol is rather conservative in dropping collinear columns
    # If there are three constant columns, it may be that only one of them gets dropped
    # Also need to have at least one term in xterms for basecol to work
    yxcols2 = Dict(yxterms[term(:oop_spend)]=>hrs.oop_spend, yxterms[term(:male)]=>hrs.male)
    nt1 = merge(nt1, (xterms=TermSet(term(:male), term(0)), treatcells=treatcells1,
        yxcols=yxcols2, treatcols=treatcols1))
    @test_throws ErrorException solveleastsquares!(nt1...)
    
    @test SolveLeastSquares()(nt) == merge(nt, ret)
end

@testset "EstVcov" begin
    hrs = exampledata("hrs")
    N = size(hrs, 1)
    col0 = convert(Vector{Float64}, (hrs.wave_hosp.==10).&(hrs.wave.==10))
    col1 = convert(Vector{Float64}, (hrs.wave_hosp.==10).&(hrs.wave.==11))
    y = convert(Vector{Float64}, hrs.oop_spend)
    X = hcat(col0, col1, ones(N, 1))
    crossx = cholesky!(Symmetric(X'X))
    cf = crossx \ (X'y)
    residuals = y - X * cf
    nt = (data=hrs, esample=trues(N), vce=Vcov.simple(), coef=cf, X=X, crossx=crossx,
        residuals=residuals, xterms=AbstractTerm[term(1)], fes=FixedEffect[],
        has_fe_intercept=false)
    ret = estvcov(nt...)
    # Compare estimates with Stata
    # reg oop_spend col0 col1
    # mat list e(V)
    @test ret.vcov_mat[1,1] ≈ 388844.2 atol=0.1
    @test ret.vcov_mat[2,2] ≈ 388844.2 atol=0.1
    @test ret.vcov_mat[3,3] ≈ 20334.169 atol=1e-3
    @test ret.vcov_mat[2,1] ≈ 20334.169 atol=1e-3
    @test ret.vcov_mat[3,1] ≈ -20334.169 atol=1e-3
    @test ret.dof_resid == N - 3
    @test ret.F ≈ 10.68532285556941 atol=1e-6

    nt = merge(nt, (vce=Vcov.robust(), fes=FixedEffect[]))
    ret = estvcov(nt...)
    # Compare estimates with Stata
    # reg oop_spend col0 col1, r
    # mat list e(V)
    @test ret.vcov_mat[1,1] ≈ 815817.44 atol=0.1
    @test ret.vcov_mat[2,2] ≈ 254993.93 atol=1e-2
    @test ret.vcov_mat[3,3] ≈ 19436.209 atol=1e-3
    @test ret.vcov_mat[2,1] ≈ 19436.209 atol=1e-3
    @test ret.vcov_mat[3,1] ≈ -19436.209 atol=1e-3
    @test ret.dof_resid == N - 3
    @test ret.F ≈ 5.371847047691197 atol=1e-6

    nt = merge(nt, (vce=Vcov.cluster(:hhidpn),))
    ret = estvcov(nt...)
    # Compare estimates with Stata
    # reghdfe oop_spend col0 col1, noa clu(hhidpn)
    # mat list e(V)
    @test ret.vcov_mat[1,1] ≈ 744005.01 atol=0.1
    @test ret.vcov_mat[2,2] ≈ 242011.45 atol=1e-2
    @test ret.vcov_mat[3,3] ≈ 28067.783 atol=1e-3
    @test ret.vcov_mat[2,1] ≈ 94113.386 atol=1e-2
    @test ret.vcov_mat[3,1] ≈ 12640.559 atol=1e-2
    @test ret.dof_resid == N - 3
    @test ret.F ≈ 5.542094561672688 atol=1e-6

    fes = FixedEffect[FixedEffect(hrs.hhidpn)]
    wt = uweights(N)
    feM = AbstractFixedEffectSolver{Float64}(fes, wt, Val{:cpu}, Threads.nthreads())
    X = hcat(col0, col1)
    _feresiduals!(Combination(y, X), feM, 1e-8, 10000)
    crossx = cholesky!(Symmetric(X'X))
    cf = crossx \ (X'y)
    residuals = y - X * cf
    nt = merge(nt, (vce=Vcov.robust(), coef=cf, X=X, crossx=crossx, residuals=residuals,
        xterms=AbstractTerm[], fes=fes, has_fe_intercept=true))
    ret = estvcov(nt...)
    # Compare estimates with Stata
    # reghdfe oop_spend col0 col1, a(hhidpn) vce(robust)
    # mat list e(V)
    @test ret.vcov_mat[1,1] ≈ 654959.97 atol=0.1
    @test ret.vcov_mat[2,2] ≈ 503679.27 atol=0.1
    @test ret.vcov_mat[2,1] ≈ 192866.2 atol=0.1
    @test ret.dof_resid == N - nunique(fes[1]) - 2
    @test ret.F ≈ 7.559815337537517 atol=1e-6

    nt = merge(nt, (vce=Vcov.cluster(:hhidpn),))
    ret = estvcov(nt...)
    # Compare estimates with Stata
    # reghdfe oop_spend col0 col1, a(hhidpn) clu(hhidpn)
    # mat list e(V)
    @test ret.vcov_mat[1,1] ≈ 606384.66 atol=0.1
    @test ret.vcov_mat[2,2] ≈ 404399.89 atol=0.1
    @test ret.vcov_mat[2,1] ≈ 106497.43 atol=0.1
    @test ret.dof_resid == N - 3
    @test ret.F ≈ 8.197452252592386 atol=1e-6

    @test EstVcov()(nt) == merge(nt, ret)
end

@testset "SolveLeastSquaresWeights" begin
    hrs = exampledata("hrs")
    tr = dynamic(:wave, -1)
    N = size(hrs, 1)
    col0 = convert(Vector{Float64}, (hrs.wave_hosp.==10).&(hrs.wave.==10))
    col1 = convert(Vector{Float64}, (hrs.wave_hosp.==10).&(hrs.wave.==11))
    cellnames = [:wave_hosp, :wave]
    cols = subcolumns(hrs, cellnames)
    cells, rows = cellrows(cols, findcell(cols))
    yterm = term(:oop_spend)
    yxterms = Dict(x=>apply_schema(x, schema(x, hrs), StatisticalModel)
        for x in (term(:oop_spend), term(:male)))
    
    yxcols = Dict(yxterms[term(:oop_spend)]=>convert(Vector{Float64}, hrs.oop_spend),
        yxterms[term(:male)]=>convert(Vector{Float64}, hrs.male))
    wt = uweights(N)
    fes = [FixedEffect(hrs.hhidpn)]
    feM = AbstractFixedEffectSolver{Float64}(fes, wt, Val{:cpu}, Threads.nthreads())
    y = yxcols[yxterms[term(:oop_spend)]]
    male = yxcols[yxterms[term(:male)]]
    _feresiduals!(Combination(y, male), feM, 1e-8, 10000)
    X = hcat(col0, col1)
    crossx = cholesky!(Symmetric(X'X))
    cf = crossx \ (X'y)
    treatcells = VecColumnTable((rel=[0, 1],))

    nt = (tr=tr, solvelsweights=true, lswtnames=(), cells=cells, rows=rows,
        X=X, crossx=crossx, coef=cf, treatcells=treatcells, yterm=yterm, xterms=AbstractTerm[],
        yxterms=yxterms, yxcols=yxcols, feM=feM, fetol=1e-8, femaxiter=10000, weights=wt)
    ret = solveleastsquaresweights(nt...)
    lswt = ret.lsweights
    @test lswt.r === cells
    @test lswt.c === treatcells
    @test all(lswt[lswt.r.wave_hosp.==10, 1] .≈ [-0.2, -0.2, -0.2, 0.8, -0.2])
    @test all(lswt[lswt.r.wave_hosp.==10, 2] .≈ [-0.2, -0.2, -0.2, -0.2, 0.8])
    @test all(x->x≈0, lswt[lswt.r.wave_hosp.!=10, :])
    @test ret.ycellweights == ret.ycellcounts == length.(rows)
    @test all(i->ret.ycellmeans[i] == sum(y[rows[i]])/length(rows[i]), 1:length(rows))

    nt0 = merge(nt, (lswtnames=(:no,),))
    @test_throws ArgumentError solveleastsquaresweights(nt0...)

    nt = merge(nt, (lswtnames=(:wave,),))
    ret = solveleastsquaresweights(nt...)
    lswt = ret.lsweights
    @test size(lswt.r) == (5, 1)
    @test lswt.r.wave == 7:11

    nt = merge(nt, (lswtnames=(:wave, :wave_hosp),))
    ret = solveleastsquaresweights(nt...)
    lswt = ret.lsweights
    @test size(lswt.r) == (20, 2)
    @test lswt.r.wave == repeat(7:11, inner=4)
    @test lswt.r.wave_hosp == repeat(8:11, outer=5)
    @test all(lswt[lswt.r.wave_hosp.==10, 1] .≈ [-0.2, -0.2, -0.2, 0.8, -0.2])
    @test all(lswt[lswt.r.wave_hosp.==10, 2] .≈ [-0.2, -0.2, -0.2, -0.2, 0.8])

    X = hcat(X, male)
    crossx = cholesky!(Symmetric(X'X))
    cf = crossx \ (X'y)
    xterms = AbstractTerm[yxterms[term(:male)]]
    nt = merge(nt, (lswtnames=(:wave_hosp, :wave), X=X, crossx=crossx,
        xterms=xterms, coef=cf))
    ret = solveleastsquaresweights(nt...)
    lswt = ret.lsweights
    w1 = -0.20813279638542392
    w2 = -0.18780080542186434
    @test all(lswt[lswt.r.wave_hosp.==10, 1] .≈ [w1, w1, w1, 0.812199194578136, w2])
    @test all(lswt[lswt.r.wave_hosp.==10, 2] .≈ [w1, w1, w1, w2, 0.812199194578136])
    @test all(x->isapprox(x, 0, atol=1e-16), lswt[lswt.r.wave_hosp.!=10, :])
    y1 = y.- cf[3].*male
    @test all(i->ret.ycellmeans[i] == sum(y1[rows[i]])/length(rows[i]), 1:length(rows))

    @test SolveLeastSquaresWeights()(nt) == merge(nt, ret)
end
