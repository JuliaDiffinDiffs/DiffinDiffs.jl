@testset "CheckVcov" begin
    hrs = exampledata("hrs")
    nt = (data=hrs, esample=trues(size(hrs,1)), aux=trues(size(hrs,1)), vce=Vcov.robust())
    @test checkvcov!(nt...) == NamedTuple()
    nt = merge(nt, (vce=Vcov.cluster(:hhidpn),))
    @test checkvcov!(nt...) == (esample=trues(size(hrs,1)),)

    df = DataFrame(hrs)
    allowmissing!(df, :hhidpn)
    nt = merge(nt, (data=df,))
    @test checkvcov!(nt...) == (esample=trues(size(hrs,1)),)

    @test CheckVcov()((data=hrs, esample=trues(size(hrs,1)), aux=trues(size(hrs,1)))) ==
        (data=hrs, esample=trues(size(hrs,1)), aux=trues(size(hrs,1)))
end

@testset "ParseFEterms" begin
    hrs = exampledata(:hrs)

    ret = parsefeterms!(TermSet())
    @test (ret...,) == (TermSet(), Set{FETerm}(), false)
    ts = TermSet((term(1), term(:male)))
    ret = parsefeterms!(ts)
    @test (ret...,) == (ts, Set{FETerm}(), false)

    ts = TermSet(term(1)+term(:male)+fe(:hhidpn))
    ret = parsefeterms!(ts)
    @test (ret...,) == (TermSet(InterceptTerm{false}(), term(:male)),
        Set(([:hhidpn]=>Symbol[],)), true)

    ts = TermSet(fe(:wave)+fe(:hhidpn))
    ret = parsefeterms!(ts)
    @test (ret...,) == (TermSet(InterceptTerm{false}()),
        Set(([:hhidpn]=>Symbol[], [:wave]=>Symbol[])), true)

    # Verify that no change is made on intercept
    ts = TermSet((term(:male), fe(:hhidpn)&term(:wave)))
    ret = parsefeterms!(ts)
    @test (ret...,) == (TermSet(term(:male)), Set(([:hhidpn]=>[:wave],)), false)

    ts = TermSet((term(:male), fe(:hhidpn)&term(:wave)))
    nt = (xterms=ts,)
    @test ParseFEterms()(nt) == (xterms=TermSet(term(:male)),
        feterms=Set(([:hhidpn]=>[:wave],)), has_fe_intercept=false)
end

@testset "GroupFEterms" begin
    nt = (feterms=Set(([:hhidpn]=>[:wave],)),)
    @test groupfeterms(nt...) === nt
    _byid(GroupFEterms()) == false
    @test GroupFEterms()(nt) === nt
end

@testset "MakeFEs" begin
    hrs = exampledata("hrs")
    @test makefes(hrs, FETerm[]) == (allfes=Dict{FETerm,FixedEffect}(),)

    feterms = [[:hhidpn]=>Symbol[], [:hhidpn,:wave]=>[:male]]
    ret = makefes(hrs, feterms)
    @test ret == (allfes=Dict{FETerm,FixedEffect}(feterms[1]=>FixedEffect(hrs.hhidpn),
        feterms[2]=>FixedEffect(hrs.hhidpn, hrs.wave, interaction=_multiply(hrs, [:male]))),)

    allntargs = NamedTuple[(feterms=Set{FETerm}(),), (feterms=Set(feterms),),
        (feterms=Set(([:hhidpn]=>Symbol[],)),)]
    @test Set(combinedargs(MakeFEs(), allntargs)...) ==
        Set(push!(feterms, [:hhidpn]=>Symbol[]))

    nt = (data=hrs, feterms=feterms)
    @test MakeFEs()(nt) == merge(nt, ret)
end

@testset "CheckFEs" begin
    hrs = exampledata("hrs")
    N = size(hrs, 1)
    nt = (feterms=Set{FETerm}(), allfes=Dict{FETerm,FixedEffect}(),
        esample=trues(N), drop_singletons=true)
    @test checkfes!(nt...) == (esample=nt.esample, fes=FixedEffect[],
        fenames=String[], nsingle=0)

    feterm = [:hhidpn]=>Symbol[]
    allfes = makefes(hrs, [[:hhidpn]=>Symbol[], [:wave]=>[:male]]).allfes
    nt = merge(nt, (feterms=Set((feterm,)), allfes=allfes))
    @test checkfes!(nt...) == (esample=trues(N), fes=[FixedEffect(hrs.hhidpn)],
        fenames=["fe_hhidpn"], nsingle=0)
    
    # fes are sorted by name
    feterms = Set(([:wave]=>Symbol[], [:hhidpn]=>Symbol[]))
    allfes = makefes(hrs, [[:hhidpn]=>Symbol[], [:wave]=>Symbol[]]).allfes
    nt = merge(nt, (feterms=feterms, allfes=allfes))
    @test checkfes!(nt...) == (esample=trues(N),
        fes=[FixedEffect(hrs.hhidpn), FixedEffect(hrs.wave)],
        fenames=["fe_hhidpn", "fe_wave"], nsingle=0)

    df = DataFrame(hrs)
    df = df[(df.wave.==7).|((df.wave.==8).&(df.wave_hosp.==8)), :]
    N = size(df, 1)
    feterm = [:hhidpn]=>Symbol[]
    allfes = makefes(df, [[:hhidpn]=>Symbol[]]).allfes
    nt = merge(nt, (feterms=Set((feterm,)), allfes=allfes, esample=trues(N)))
    kept = df.wave_hosp.==8
    @test checkfes!(nt...) == (esample=kept, fes=[FixedEffect(df.hhidpn)[kept]],
        fenames=["fe_hhidpn"], nsingle=N-sum(kept))

    df = df[df.wave.==7, :]
    N = size(df, 1)
    allfes = makefes(df, [[:hhidpn]=>Symbol[]]).allfes
    nt = merge(nt, (allfes=allfes, esample=trues(N)))
    @test_throws ErrorException checkfes!(nt...)

    nt = merge(nt, (esample=trues(N),))
    @test_throws ErrorException CheckFEs()(nt)
    nt = merge(nt, (esample=trues(N), drop_singletons=false))
    @test CheckFEs()(nt) == merge(nt, (fes=[FixedEffect(df.hhidpn)],
        fenames=["fe_hhidpn"], nsingle=0))
end

@testset "MakeFESolver" begin
    hrs = exampledata("hrs")
    N = size(hrs, 1)
    fes = FixedEffect[FixedEffect(hrs.hhidpn)]
    fenames = [:fe_hhidpn]
    nt = (fes=fes, weights=uweights(N), default(MakeFESolver())...)
    ret = makefesolver(nt...)
    @test ret.feM isa FixedEffects.FixedEffectSolverCPU{Float64}
    nt = merge(nt, (fes=FixedEffect[],))
    @test makefesolver(nt...) == (feM=nothing,)
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
    ret = maketreatcols(nt..., tr.time, Dict(-1=>1), IdDict{ValidTimeType,Int}(11=>1))
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
    ret1 = maketreatcols(nt..., tr.time, Dict(-1=>1), IdDict{ValidTimeType,Int}(11=>1))
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
    ret2 = maketreatcols(nt..., tr.time, Dict(-1=>1), IdDict{ValidTimeType,Int}(11=>1))
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
    ret3 = maketreatcols(nt..., tr.time, Dict(-1=>1), IdDict{ValidTimeType,Int}(11=>1))
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
    ret = maketreatcols(nt..., tr.time, Dict(-1=>1), IdDict{ValidTimeType,Int}(11=>1))
    col = reshape(col[esample], N, 1)
    defaults = (default(MakeTreatCols())...,)
    _feresiduals!(col, feM, defaults[2:3]...)
    @test ret.treatcols[1] == (col.*sqrt.(wt))[:]
    @test ret.cellcounts == [252, 252, 252, 251, 176, 176, 176, 175, 162, 160, 163, 162]
    @test ret.cellweights[1] == 1776173

    allntargs = NamedTuple[(tr=tr, pr=pr)]
    @test combinedargs(MakeTreatCols(), allntargs) ==
        (Dict(-1=>1), IdDict{ValidTimeType,Int}(11=>1))
    push!(allntargs, allntargs[1])
    @test combinedargs(MakeTreatCols(), allntargs) ==
        (Dict(-1=>2), IdDict{ValidTimeType,Int}(11=>2))
    push!(allntargs, (tr=dynamic(:wave, [-1,-2]), pr=nevertreated(10:11)))
    @test combinedargs(MakeTreatCols(), allntargs) ==
        (Dict(-1=>3), IdDict{ValidTimeType,Int}(11=>3))
    push!(allntargs, (tr=dynamic(:wave, [-3]), pr=nevertreated(10)))
    @test combinedargs(MakeTreatCols(), allntargs) ==
        (Dict{Int,Int}(), IdDict{ValidTimeType,Int}())

    allntargs = NamedTuple[(tr=tr, pr=pr), (tr=tr, pr=unspecifiedpr())]
    @test combinedargs(MakeTreatCols(), allntargs) ==
        (Dict(-1=>2), IdDict{ValidTimeType,Int}())

    df.wave = settime(Date.(hrs.wave), Year(1))
    df.wave_hosp = settime(Date.(hrs.wave_hosp), Year(1), start=Date(7))
    ret1 = maketreatcols(nt..., tr.time,
        Dict(-1=>1), IdDict{ValidTimeType,Int}(Date(11)=>1))
    @test ret1.cells[1] == Date.(ret.cells[1])
    @test ret1.cells[2] == Date.(ret.cells[2])
    @test ret1.rows == ret.rows
    @test ret1.treatcells[1] == Date.(ret.treatcells[1])
    @test ret1.treatcells[2] == ret.treatcells[2]
    @test ret1.treatrows == ret.treatrows
    @test ret1.treatcols == ret.treatcols
    @test ret1.cellweights == ret.cellweights
    @test ret1.cellcounts == ret.cellcounts

    rot = ifelse.(isodd.(hrs.hhidpn), 1, 2)
    df.wave = RotatingTimeArray(rot, hrs.wave)
    df.wave_hosp = RotatingTimeArray(rot, hrs.wave_hosp)
    e = rotatingtime((1,1,2), (10,11,11))
    ret2 = maketreatcols(nt..., tr.time,
        Dict(-1=>1), IdDict{ValidTimeType,Int}(c=>1 for c in e))
    @test ret2.cells[1] == sort!(append!((rotatingtime(r, ret.cells[1]) for r in (1,2))...))
    rt = append!((rotatingtime(r, 7:11) for r in (1,2))...)
    @test ret2.cells[2] == repeat(rt, 4)
    @test size(ret2.treatcells) == (20, 2)
    @test sort!(unique(ret2.treatcells[1])) ==
        sort!(append!(rotatingtime(1, 8:9), rotatingtime(2, 8:10)))
    
    df.wave = settime(Date.(hrs.wave), Year(1), rotation=rot)
    df.wave_hosp = settime(Date.(hrs.wave_hosp), Year(1), start=Date(7), rotation=rot)
    e = rotatingtime((1,1,2), Date.((10,11,11)))
    ret3 = maketreatcols(nt..., tr.time,
        Dict(-1=>1), IdDict{ValidTimeType,Int}(c=>1 for c in e))
    @test ret3.cells[1].time == Date.(ret2.cells[1].time)
    @test ret3.cells[2].time == Date.(ret2.cells[2].time)
    @test ret3.rows == ret2.rows
    @test ret3.treatcells[1].time == Date.(ret2.treatcells[1].time)
    @test ret3.treatcells[2] == ret2.treatcells[2]
    @test ret3.treatrows == ret2.treatrows
    @test ret3.treatcols == ret2.treatcols
    @test ret3.cellweights == ret2.cellweights
    @test ret3.cellcounts == ret2.cellcounts

    nt = merge(nt, (data=hrs, tr=tr, pr=pr))
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
    @test ret.basiscols == trues(3)

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
    @test sum(ret1.basiscols) == 3

    treatcells1 = VecColumnTable((rel=[0, 1, 1, 1], wave_hosp=[10, 10, 0, 1]))
    treatcols1 = push!(copy(treatcols0), ones(N), ones(N))
    # basecol is rather conservative in dropping collinear columns
    # If there are three constant columns, it may be that only one of them gets dropped
    # Also need to have at least one term in xterms for basiscol to work
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
    
    yxcols = Dict(yxterms[term(:oop_spend)]=>convert(Vector{Float64}, hrs.oop_spend))
    wt = uweights(N)
    fes = [FixedEffect(hrs.hhidpn)]
    feM = AbstractFixedEffectSolver{Float64}(fes, wt, Val{:cpu}, Threads.nthreads())
    y = yxcols[yxterms[term(:oop_spend)]]
    fetol = 1e-8
    _feresiduals!(Combination(y, col0, col1), feM, fetol, 10000)
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
    @test lswt[lswt.r.wave_hosp.==10, 1] ≈ [-1/3, -1/3, -1/3, 1, 0] atol=fetol
    @test lswt[lswt.r.wave_hosp.==10, 1] ≈ [-1/3, -1/3, -1/3, 1, 0] atol=fetol
    @test lswt[lswt.r.wave_hosp.==10, 2] ≈ [-1/3, -1/3, -1/3, 0, 1] atol=fetol
    @test all(x->isapprox(x, 0, atol=fetol), lswt[lswt.r.wave_hosp.!=10, :])
    @test ret.ycellweights == ret.ycellcounts == length.(rows)
    @test all(i->ret.ycellmeans[i] ≈ sum(y[rows[i]])/length(rows[i]), 1:length(rows))

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
    @test lswt[lswt.r.wave_hosp.==10, 1] ≈ [-1/3, -1/3, -1/3, 1, 0] atol=fetol
    @test lswt[lswt.r.wave_hosp.==10, 2] ≈ [-1/3, -1/3, -1/3, 0, 1] atol=fetol

    df = DataFrame(hrs)
    df.x = zeros(N)
    df.x[df.wave.==7] .= rand(656)
    yxterms = Dict(x=>apply_schema(x, schema(x, df), StatisticalModel)
        for x in (term(:oop_spend), term(:x)))
    yxcols = Dict(yxterms[term(:oop_spend)]=>convert(Vector{Float64}, hrs.oop_spend),
        yxterms[term(:x)]=>convert(Vector{Float64}, df.x))
    fes = [FixedEffect(hrs.hhidpn), FixedEffect(hrs.wave)]
    feM = AbstractFixedEffectSolver{Float64}(fes, wt, Val{:cpu}, Threads.nthreads())
    y = yxcols[yxterms[term(:oop_spend)]]
    x = yxcols[yxterms[term(:x)]]
    _feresiduals!(Combination(y, col0, col1, x), feM, fetol, 10000)
    X = hcat(col0, col1, x)
    crossx = cholesky!(Symmetric(X'X))
    cf = crossx \ (X'y)
    xterms = AbstractTerm[yxterms[term(:x)]]
    nt = merge(nt, (lswtnames=(:wave_hosp, :wave), X=X, crossx=crossx, coef=cf,
        xterms=xterms, yxterms=yxterms, yxcols=yxcols))
    ret = solveleastsquaresweights(nt...)
    lswt = ret.lsweights
    @test lswt[lswt.r.wave.<=9, 1] ≈ lswt[lswt.r.wave.<=9, 2]
    @test lswt[lswt.r.wave.==10, 1] ≈ lswt[lswt.r.wave.==11, 2]
    @test lswt[lswt.r.wave.==11, 1] ≈ lswt[lswt.r.wave.==10, 2]
    y1 = y .- cf[3].*x
    @test all(i->ret.ycellmeans[i] == sum(y1[rows[i]])/length(rows[i]), 1:length(rows))

    @test SolveLeastSquaresWeights()(nt) == merge(nt, ret)
end
