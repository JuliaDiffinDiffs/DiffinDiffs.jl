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
    nt = (data=hrs, esample=trues(size(hrs,1)), xterms=(term(:white),), drop_singletons=true)
    @test checkfes!(nt...) == (xterms=(term(:white),), esample=trues(size(hrs,1)),
        fes=FixedEffect[], fenames=Symbol[], has_fe_intercept=false, nsingle=0)
    nt = merge(nt, (xterms=(fe(:hhidpn),),))
    @test checkfes!(nt...) == (xterms=(InterceptTerm{false}(),), esample=trues(size(hrs,1)),
        fes=[FixedEffect(hrs.hhidpn)], fenames=[:fe_hhidpn], has_fe_intercept=true, nsingle=0)
    
    df = DataFrame(hrs)
    df = df[(df.wave.==7).|((df.wave.==8).&(df.wave_hosp.==8)), :]
    nobs = size(df, 1)
    nt = merge(nt, (data=df, esample=trues(nobs)))
    kept = df.wave_hosp.==8
    @test checkfes!(nt...) == (xterms=(InterceptTerm{false}(),), esample=kept,
        fes=[FixedEffect(df.hhidpn)], fenames=[:fe_hhidpn], has_fe_intercept=true,
        nsingle=nobs-sum(kept))

    df = df[df.wave.==7, :]
    nobs = size(df, 1)
    nt = merge(nt, (data=df, esample=trues(nobs)))
    @test_throws ErrorException checkfes!(nt...)

    @test_throws ErrorException CheckFEs()(nt)
    nt = merge(nt, (drop_singletons=false, esample=trues(nobs)))
    @test CheckFEs()(nt) == merge(nt, (xterms=(InterceptTerm{false}(),),
        fes=[FixedEffect(df.hhidpn)], fenames=[:fe_hhidpn], has_fe_intercept=true, nsingle=0))
end

@testset "MakeFESolver" begin
    hrs = exampledata("hrs")
    nobs = size(hrs, 1)
    fes = FixedEffect[FixedEffect(hrs.hhidpn)]
    fenames = [:fe_hhidpn]
    nt = (fenames=fenames, weights=uweights(nobs), esample=trues(nobs),
        default(MakeFESolver())..., fes=fes)
    ret = makefesolver(nt...)
    @test ret.feM isa FixedEffects.FixedEffectSolverCPU{Float64}
    nt = merge(nt, (fenames=Symbol[], fes=FixedEffect[]))
    @test makefesolver(nt...) == (feM=nothing,)
    @test MakeFESolver()(nt) == merge(nt, (feM=nothing,))
end

@testset "MakeYXCols" begin
    hrs = exampledata("hrs")
    nobs = size(hrs, 1)
    t1 = InterceptTerm{true}()
    nt = (data=hrs, weights=uweights(nobs), esample=trues(nobs), feM=nothing, has_fe_intercept=false, default(MakeYXCols())...)
    ret = makeyxcols(nt..., (term(:oop_spend),), (term(1),))
    @test ret.yxcols == Dict(term(:oop_spend)=>hrs.oop_spend, t1=>ones(nobs, 1))
    @test ret.yxterms[term(:oop_spend)] isa ContinuousTerm
    @test ret.yxterms[t1] isa InterceptTerm{true}
    @test ret.nfeiterations === nothing
    @test ret.feconverged === nothing

    # Verify that an intercept will be added if not having one
    ret1 = makeyxcols(nt..., (term(:oop_spend),), ())
    @test ret1 == ret
    ret1 = makeyxcols(nt..., (term(:oop_spend),), (term(0),))
    @test ret1.yxcols == ret.yxcols
    @test ret1.yxterms[t1] isa InterceptTerm{true}

    wt = Weights(hrs.rwthh)
    nt = merge(nt, (weights=wt,))
    ret = makeyxcols(nt..., (term(:oop_spend), term(:riearnsemp)), (term(:male),))
    @test ret.yxcols == Dict(term(:oop_spend)=>hrs.oop_spend.*sqrt.(wt),
        term(:riearnsemp)=>hrs.riearnsemp.*sqrt.(wt),
        term(:male)=>reshape(hrs.male.*sqrt.(wt), nobs, 1),
        t1=>reshape(sqrt.(wt), nobs, 1))

    df = DataFrame(hrs)
    df.riearnsemp[1] = NaN
    nt = merge(nt, (data=df,))
    @test_throws ErrorException makeyxcols(nt..., (term(:riearnsemp),), (term(1),))
    df.spouse = convert(Vector{Float64}, df.spouse)
    df.spouse[1] = Inf
    @test_throws ErrorException makeyxcols(nt..., (term(:oop_spend),), (term(:spouse),))

    df = DataFrame(hrs)
    x = randn(nobs)
    df.x = x
    wt = uweights(nobs)
    fes = [FixedEffect(df.hhidpn)]
    feM = AbstractFixedEffectSolver{Float64}(fes, wt, Val{:cpu}, Threads.nthreads())
    nt = merge(nt, (data=df, weights=wt, feM=feM, has_fe_intercept=true))
    ret = makeyxcols(nt..., (term(:oop_spend),), (InterceptTerm{false}(), term(:x)))
    resids = reshape(copy(df.oop_spend), nobs, 1)
    _feresiduals!(resids, feM, 1e-8, 10000)
    resids .*= sqrt.(wt)
    @test ret.yxcols[term(:oop_spend)] == reshape(resids, nobs)
    # Verify input data are not modified
    @test df.oop_spend == hrs.oop_spend
    @test df.x == x

    df = DataFrame(hrs)
    esample = df.rwthh.> 0
    nobs = sum(esample)
    wt = Weights(hrs.rwthh[esample])
    fes = [FixedEffect(df.hhidpn[esample])]
    feM = AbstractFixedEffectSolver{Float64}(fes, wt, Val{:cpu}, Threads.nthreads())
    nt = merge(nt, (data=df, esample=esample, weights=wt, feM=feM, has_fe_intercept=true))
    ret = makeyxcols(nt..., (term(:oop_spend),), (InterceptTerm{false}(),))
    resids = reshape(df.oop_spend[esample], nobs, 1)
    _feresiduals!(resids, feM, 1e-8, 10000)
    resids .*= sqrt.(wt)
    @test ret.yxcols == Dict(term(:oop_spend)=>reshape(resids, nobs))
    @test ret.nfeiterations isa Int
    @test ret.feconverged
    # Verify input data are not modified
    @test df.oop_spend == hrs.oop_spend

    allntargs = NamedTuple[(yterm=term(:oop_spend), xterms=())]
    @test combinedargs(MakeYXCols(), allntargs) == ((term(:oop_spend),), ())
    push!(allntargs, allntargs[1])
    @test combinedargs(MakeYXCols(), allntargs) == ((term(:oop_spend),), ())
    push!(allntargs, (yterm=term(:riearnsemp), xterms=(InterceptTerm{false}(),)))
    @test combinedargs(MakeYXCols(), allntargs) ==
        ((term(:oop_spend),term(:riearnsemp)), (InterceptTerm{false}(),))
    push!(allntargs, (yterm=term(:riearnsemp), xterms=(term(:male),)))
    @test combinedargs(MakeYXCols(), allntargs) ==
        ((term(:oop_spend),term(:riearnsemp)),
        (InterceptTerm{false}(), term(:male)))
    
    nt = merge(nt, (data=df, yterm=term(:oop_spend), xterms=(InterceptTerm{false}(),)))
    @test MakeYXCols()(nt) == merge(nt, ret)
end

@testset "MakeTreatCols" begin
    hrs = exampledata("hrs")
    nobs = size(hrs, 1)
    tr = dynamic(:wave, -1)
    nt = (data=hrs, treatname=:wave_hosp, treatintterms=(), feM=nothing,
        weightname=nothing, weights=uweights(nobs), esample=trues(nobs),
        tr_rows=hrs.wave_hosp.!=11, default(MakeTreatCols())...)
    ret = maketreatcols(nt..., typeof(tr), tr.time, Set([-1]))
    @test length(ret.itreats) == 12
    @test ret.itreats[(rel=0, wave_hosp=10)] ==
        collect(1:nobs)[(hrs.wave_hosp.==10).&(hrs.wave.==10)]
    col = convert(Vector{Float64}, (hrs.wave_hosp.==10).&(hrs.wave.==10))
    @test ret.treatcols[(rel=0, wave_hosp=10)] == col
    @test ret.cellweights == ret.cellcounts
    w = ret.cellweights
    @test all(x->x==252, getindices(w, filter(x->x.wave_hosp==8, keys(w))))
    @test all(x->x==176, getindices(w, filter(x->x.wave_hosp==9, keys(w))))
    @test all(x->x==163, getindices(w, filter(x->x.wave_hosp==10, keys(w))))

    nt = merge(nt, (treatintterms=(term(:male),),))
    ret = maketreatcols(nt..., typeof(tr), tr.time, Set([-1]))
    @test length(ret.itreats) == 24
    @test ret.itreats[(rel=0, wave_hosp=10, male=1)] ==
        collect(1:nobs)[(hrs.wave_hosp.==10).&(hrs.wave.==10).&(hrs.male.==1)]

    nt = merge(nt, (cohortinteracted=false, treatintterms=()))
    ret = maketreatcols(nt..., typeof(tr), tr.time, Set([-1]))
    @test length(ret.itreats) == 6
    @test ret.itreats[(rel=0,)] ==
        collect(1:nobs)[(hrs.wave_hosp.==hrs.wave).&(hrs.wave_hosp.!=11)]
    col1 = convert(Vector{Float64}, (hrs.wave_hosp.==hrs.wave).&(hrs.wave_hosp.!=11))
    @test ret.treatcols[(rel=0,)] == col1

    nt = merge(nt, (treatintterms=(term(:male),),))
    ret = maketreatcols(nt..., typeof(tr), tr.time, Set([-1]))
    @test length(ret.itreats) == 12
    @test ret.itreats[(rel=0, male=1)] ==
        collect(1:nobs)[(hrs.wave_hosp.==hrs.wave).&(hrs.wave_hosp.!=11).&(hrs.male.==1)]

    df = DataFrame(hrs)
    esample = df.rwthh.> 0
    nobs = sum(esample)
    wt = Weights(hrs.rwthh[esample])
    fes = [FixedEffect(df.hhidpn[esample])]
    feM = AbstractFixedEffectSolver{Float64}(fes, wt, Val{:cpu}, Threads.nthreads())
    nt = merge(nt, (data=df, feM=feM, weightname=:rwthh, weights=wt, esample=esample,
        treatintterms=(), cohortinteracted=true))
    ret = maketreatcols(nt..., typeof(tr), tr.time, Set([-1]))
    col = reshape(col[esample], nobs, 1)
    defaults = (default(MakeTreatCols())...,)
    _feresiduals!(col, feM, defaults[[2,3]]...)
    @test ret.treatcols[(rel=0, wave_hosp=10)] == (col.*sqrt.(wt))[:]
    @test ret.cellcounts == w
    @test ret.cellweights[(rel=0, wave_hosp=10)] == 881700

    allntargs = NamedTuple[(tr=tr,)]
    @test combinedargs(MakeTreatCols(), allntargs) == (Set([-1]),)
    push!(allntargs, allntargs[1])
    @test combinedargs(MakeTreatCols(), allntargs) == (Set([-1]),)
    push!(allntargs, (tr=dynamic(:wave, [-1,-2]),))
    @test combinedargs(MakeTreatCols(), allntargs) == (Set([-1]),)
    push!(allntargs, (tr=dynamic(:wave, [-3]),))
    @test combinedargs(MakeTreatCols(), allntargs) == (Set{Int}(),)

    nt = merge(nt, (tr=tr,))
    @test MakeTreatCols()(nt) == merge(nt, (itreats=ret.itreats, treatcols=ret.treatcols,
        cellweights=ret.cellweights, cellcounts=ret.cellcounts))
end

@testset "SolveLeastSquares" begin
    hrs = exampledata("hrs")
    nobs = size(hrs, 1)
    df = DataFrame(hrs)
    df.t2 = fill(2.0, nobs)
    t1 = InterceptTerm{true}()
    t0 = InterceptTerm{false}()
    tr = dynamic(:wave, -1)
    yxterms = Dict([x=>apply_schema(x, schema(x, df), StatisticalModel)
        for x in (term(:oop_spend), t1, term(:t2), t0, term(:male))])
    yxcols0 = Dict(term(:oop_spend)=>hrs.oop_spend, t1=>ones(nobs, 1))
    col0 = convert(Vector{Float64}, (hrs.wave_hosp.==10).&(hrs.wave.==10))
    col1 = convert(Vector{Float64}, (hrs.wave_hosp.==10).&(hrs.wave.==11))
    tcols0 = Dictionary([(rel=0, wave_hosp=10), (rel=1, wave_hosp=10)], [col0, col1])
    nt = (tr=tr, yterm=term(:oop_spend), xterms=(term(1),), yxterms=yxterms,
        yxcols=yxcols0, treatcols=tcols0, has_fe_intercept=false)
    ret = solveleastsquares!(nt...)
    # Compare estimates with Stata
    # gen col0 = wave_hosp==10 & wave==10
    # gen col1 = wave_hosp==10 & wave==11
    # reg oop_spend col0 col1
    @test ret.coef[1] ≈ 2862.4141 atol=1e-4
    @test ret.coef[2] ≈ 490.44869 atol=1e-4
    @test ret.coef[3] ≈ 3353.6565 atol=1e-4
    @test ret.basecols == trues(3)
    @test ret.treatinds.rel == [0, 1]
    @test ret.treatinds.wave_hosp == [10, 10]

    # Verify that an intercept will be added if needed
    nt1 = merge(nt, (xterms=(),))
    ret1 = solveleastsquares!(nt1...)
    @test ret1 == ret
    nt1 = merge(nt, (xterms=(term(0),),))
    ret1 = solveleastsquares!(nt1...)
    @test ret1.xterms == (t0,)
    @test size(ret1.X, 2) == 2

    # Test colliner xterms are handled
    yxcols1 = Dict(term(:oop_spend)=>hrs.oop_spend, t1=>ones(nobs), term(:t2)=>df.t2)
    nt1 = merge(nt, (xterms=(term(1), term(:t2)), yxcols=yxcols1))
    ret1 = solveleastsquares!(nt1...)
    @test ret1.coef[1:2] == ret.coef[1:2]
    @test sum(ret1.basecols) == 3

    insert!(tcols0, (rel=1, wave_hosp=0), ones(nobs))
    insert!(tcols0, (rel=1, wave_hosp=1), ones(nobs))
    # basecol is rather conservative in dropping collinear columns
    # If there are three constant columns, it may be that only one of them gets dropped
    # Also need to have at least one term in xterms for basecol to work
    yxcols2 = Dict(term(:oop_spend)=>hrs.oop_spend, term(:male)=>hrs.male)
    nt1 = merge(nt1, (xterms=(term(:male), term(0)), yxcols=yxcols2, treatcols=tcols0))
    @test_throws ErrorException solveleastsquares!(nt1...)
    delete!(tcols0, (rel=1, wave_hosp=0))
    delete!(tcols0, (rel=1, wave_hosp=1))
    
    @test SolveLeastSquares()(nt) == merge(nt, ret)
end

@testset "EstVcov" begin
    hrs = exampledata("hrs")
    nobs = size(hrs, 1)
    col0 = convert(Vector{Float64}, (hrs.wave_hosp.==10).&(hrs.wave.==10))
    col1 = convert(Vector{Float64}, (hrs.wave_hosp.==10).&(hrs.wave.==11))
    y = convert(Vector{Float64}, hrs.oop_spend)
    X = hcat(col0, col1, ones(nobs, 1))
    crossx = cholesky!(Symmetric(X'X))
    coef = crossx \ (X'y)
    residuals = y - X * coef
    nt = (data=hrs, esample=trues(nobs), vce=Vcov.simple(), coef=coef,
        X=X, crossx=crossx, residuals=residuals, xterms=(term(1),), fes=FixedEffect[],
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
    @test ret.dof_resid == nobs - 3
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
    @test ret.dof_resid == nobs - 3
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
    @test ret.dof_resid == nobs - 3
    @test ret.F ≈ 5.542094561672688 atol=1e-6

    fes = FixedEffect[FixedEffect(hrs.hhidpn)]
    wt = uweights(nobs)
    feM = AbstractFixedEffectSolver{Float64}(fes, wt, Val{:cpu}, Threads.nthreads())
    X = hcat(col0, col1)
    _feresiduals!(Combination(y, X), feM, 1e-8, 10000)
    crossx = cholesky!(Symmetric(X'X))
    coef = crossx \ (X'y)
    residuals = y - X * coef
    nt = merge(nt, (vce=Vcov.robust(), coef=coef, X=X, crossx=crossx, residuals=residuals, xterms=(), fes=fes, has_fe_intercept=true))
    ret = estvcov(nt...)
    # Compare estimates with Stata
    # reghdfe oop_spend col0 col1, a(hhidpn) vce(robust)
    # mat list e(V)
    @test ret.vcov_mat[1,1] ≈ 654959.97 atol=0.1
    @test ret.vcov_mat[2,2] ≈ 503679.27 atol=0.1
    @test ret.vcov_mat[2,1] ≈ 192866.2 atol=0.1
    @test ret.dof_resid == nobs - nunique(fes[1]) - 2
    @test ret.F ≈ 7.559815337537517 atol=1e-6

    nt = merge(nt, (vce=Vcov.cluster(:hhidpn),))
    ret = estvcov(nt...)
    # Compare estimates with Stata
    # reghdfe oop_spend col0 col1, a(hhidpn) clu(hhidpn)
    # mat list e(V)
    @test ret.vcov_mat[1,1] ≈ 606384.66 atol=0.1
    @test ret.vcov_mat[2,2] ≈ 404399.89 atol=0.1
    @test ret.vcov_mat[2,1] ≈ 106497.43 atol=0.1
    @test ret.dof_resid == nobs - 3
    @test ret.F ≈ 8.197452252592386 atol=1e-6

    @test EstVcov()(nt) == merge(nt, ret)
end
