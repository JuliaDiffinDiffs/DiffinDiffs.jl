@testset "CheckData" begin
    @testset "checkdata" begin
        hrs = exampledata("hrs")
        nt = (data=hrs, subset=nothing, weightname=nothing)
        @test checkdata(nt...) == ((esample=trues(size(hrs,1)),), false)
        
        nt = merge(nt, (weightname=:rwthh, subset=hrs.male))
        @test checkdata(nt...) == ((esample=BitArray(hrs.male),), false)
        
        nt = merge(nt, (data=rand(10,10),))
        @test_throws ArgumentError checkdata(nt...)

        nt = merge(nt, (data=hrs, subset=BitArray(hrs.male[1:100])))
        @test_throws DimensionMismatch checkdata(nt...)

        nt = merge(nt, (subset=falses(size(hrs,1)),))
        @test_throws ErrorException checkdata(nt...)
    end

    @testset "StatsStep" begin
        @test sprint(show, CheckData()) == "CheckData"
        @test sprint(show, MIME("text/plain"), CheckData()) ==
            "CheckData (StatsStep that calls DiffinDiffsBase.checkdata)"

        @test _f(CheckData()) == checkdata
        @test namedargs(CheckData()) == (data=nothing, subset=nothing, weightname=nothing)

        hrs = exampledata("hrs")
        nt = (data=hrs, subset=nothing, weightname=nothing)
        @test CheckData()(nt) == merge(nt, (esample=trues(size(hrs,1)),))
        @test CheckData()((data=hrs,)) == (data=hrs, esample=trues(size(hrs,1)))
        @test_throws ArgumentError CheckData()()
    end
end 

@testset "CheckVars" begin
    @testset "checkvars!" begin
        hrs = exampledata("hrs")
        nt = (data=hrs, tr=dynamic(:wave, -1), pr=nevertreated(11), yterm=term(:oop_spend),
            treatname=:wave_hosp, treatintterms=(), xterms=(), esample=trues(size(hrs,1)))
        @test checkvars!(nt...) == ((esample=trues(size(hrs,1)),
            tr_rows=hrs.wave_hosp.!=11), false)
        
        nt = merge(nt, (pr=notyettreated(11),))
        @test checkvars!(nt...) == ((esample=hrs.wave.!=11,
            tr_rows=(hrs.wave_hosp.!=11).&(hrs.wave.!=11)), false)
        
        nt = merge(nt, (pr=notyettreated(11, 10), esample=trues(size(hrs,1))))
        @test checkvars!(nt...) ==
            ((esample=.!(hrs.wave_hosp.∈(10,)).& .!(hrs.wave.∈((10,11),)),
            tr_rows=(.!(hrs.wave_hosp.∈((10,11),)).& .!(hrs.wave.∈((10,11),)))), false)
        
        nt = merge(nt, (pr=nevertreated(11), treatintterms=(term(:male),),
            xterms=(term(:white),), esample=trues(size(hrs,1))))
        @test checkvars!(nt...) == ((esample=trues(size(hrs,1)),
            tr_rows=hrs.wave_hosp.!=11), false)
        
        df = DataFrame(hrs)
        allowmissing!(df)
        df.male .= ifelse.(df.wave_hosp.==11, missing, df.male)

        nt = merge(nt, (data=df,))
        @test checkvars!(nt...) == ((esample=trues(size(hrs,1)),
            tr_rows=hrs.wave_hosp.!=11), false)
        
        df.male .= ifelse.(df.wave_hosp.==10, missing, df.male)
        @test checkvars!(nt...) == ((esample=df.wave_hosp.!=10,
            tr_rows=hrs.wave_hosp.∈((8,9),)), false)

        df.white .= ifelse.(df.wave_hosp.==9, missing, df.white)
        @test checkvars!(nt...) == ((esample=df.wave_hosp.∈((8,11),),
            tr_rows=hrs.wave_hosp.==8), false)
    end

    @testset "StatsStep" begin
        @test sprint(show, CheckVars()) == "CheckVars"
        @test sprint(show, MIME("text/plain"), CheckVars()) ==
            "CheckVars (StatsStep that calls DiffinDiffsBase.checkvars!)"

        @test _f(CheckVars()) == checkvars!
        @test namedargs(CheckVars()) == (data=nothing, tr=nothing, pr=nothing,
            yterm=nothing, treatname=nothing, treatintterms=(), xterms=(), esample=nothing)

        hrs = exampledata("hrs")
        nt = (data=hrs, tr=dynamic(:wave, -1), pr=nevertreated(11), yterm=term(:oop_spend),
            treatname=:wave_hosp, treatintterms=(), xterms=(), esample=trues(size(hrs,1)))
        @test CheckVars()(nt) ==
            merge(nt, (esample=trues(size(hrs,1)), tr_rows=hrs.wave_hosp.!=11))
        nt = (data=hrs, tr=dynamic(:wave, -1), pr=nevertreated(11), yterm=term(:oop_spend),
            treatname=:wave_hosp, esample=trues(size(hrs,1)))
        @test CheckVars()(nt) ==
            merge(nt, (esample=trues(size(hrs,1)), tr_rows=hrs.wave_hosp.!=11))
        @test_throws MethodError CheckVars()()
    end
end

@testset "MakeWeights" begin
    @testset "makeweights" begin
        hrs = exampledata("hrs")
        nt = (data=hrs, weightname=nothing, esample=trues(size(hrs,1)))
        r, s = makeweights(nt...)
        @test r.weights isa UnitWeights && sum(r.weights) == size(hrs,1) && s

        nt = merge(nt, (weightname=:rwthh,))
        r, s = makeweights(nt...)
        @test r.weights isa Weights && sum(r.weights) == sum(hrs.rwthh) && s
    end

    @testset "StatsStep" begin
        @test sprint(show, MakeWeights()) == "MakeWeights"
        @test sprint(show, MIME("text/plain"), MakeWeights()) ==
            "MakeWeights (StatsStep that calls DiffinDiffsBase.makeweights)"

        @test _f(MakeWeights()) == makeweights
        @test namedargs(MakeWeights()) == (data=nothing, weightname=nothing, esample=nothing)

        hrs = exampledata("hrs")
        nt = (data=hrs, esample=trues(size(hrs,1)))
        r = MakeWeights()(nt)
        @test r.weights isa UnitWeights && sum(r.weights) == size(hrs,1)
    end
end

@testset "_getsubcolumns" begin
    hrs = exampledata("hrs")
    df = DataFrame(hrs)
    allowmissing!(df)
    @test _getsubcolumns(df, :wave, falses(size(df,1))).wave == Int[]
    cols = _getsubcolumns(df, :wave)
    @test cols.wave == hrs.wave
    @test eltype(cols.wave) == Int
    @test _getsubcolumns(df, :wave, df.wave.==10).wave == hrs.wave[hrs.wave.==10]

    df.male .= ifelse.(df.wave.==11, missing, df.male)
    @test_throws MethodError _getsubcolumns(df, :male)
    cols = _getsubcolumns(df, :male, df.wave.!=11)
    @test cols.male == hrs.male[hrs.wave.!=11]
    @test eltype(cols.male) == Int

    cols = _getsubcolumns(df, (:wave, :oop_spend))
    @test cols.oop_spend == hrs.oop_spend
    @test eltype(cols.oop_spend) == Float64
    @test_throws MethodError _getsubcolumns(df, (:wave, :male))
    cols = _getsubcolumns(df, (:wave, :male), df.wave.!=11)
    @test cols.wave == hrs.wave[hrs.wave.!=11]
    @test eltype(cols.wave) == Int
    @test _getsubcolumns(df, [:wave, :male], df.wave.!=11) == cols
end
