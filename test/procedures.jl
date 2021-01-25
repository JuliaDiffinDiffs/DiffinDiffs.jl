using DiffinDiffsBase: _f, checkdata, checkvars

@testset "CheckData" begin
    @testset "checkdata" begin
        hrs = exampledata("hrs")
        nt = (data=hrs, subset=nothing, weights=nothing)
        @test checkdata(nt...) == ((esample=trues(size(hrs,1)),), false)
        
        nt = merge(nt, (weights=:rwthh, subset=hrs.male))
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
        @test namedargs(CheckData()) == (data=nothing, subset=nothing, weights=nothing)

        hrs = exampledata("hrs")
        nt = (data=hrs, subset=nothing, weights=nothing)
        @test CheckData()(nt) == merge(nt, (esample=trues(size(hrs,1)),))
        @test CheckData()((data=hrs,)) == (data=hrs, esample=trues(size(hrs,1)))
        @test_throws ArgumentError CheckData()()
    end
end 

@testset "CheckVars" begin
    @testset "checkvars" begin
        hrs = exampledata("hrs")
        nt = (data=hrs, tr=dynamic(:wave, -1), pr=nevertreated(11), yterm=term(:oop_spend),
            treatname=:wave_hosp, treatintterms=(), xterms=(), esample=trues(size(hrs,1)))
        @test checkvars(nt...) == ((esample=trues(size(hrs,1)),
            tr_rows=hrs.wave_hosp.!=11), false)
        nt = (data=hrs, tr=dynamic(:wave, -1), pr=notyettreated(11), yterm=term(:oop_spend),
            treatname=:wave_hosp, treatintterms=(), xterms=(), esample=trues(size(hrs,1)))
        @test checkvars(nt...) == ((esample=hrs.wave.!=11,
            tr_rows=(hrs.wave_hosp.!=11).&(hrs.wave.!=11)), false)
        nt = (data=hrs, tr=dynamic(:wave, -1), pr=notyettreated(11, 10),
            yterm=term(:oop_spend), treatname=:wave_hosp, treatintterms=(), xterms=(),
            esample=trues(size(hrs,1)))
        @test checkvars(nt...) ==
            ((esample=.!(hrs.wave_hosp.∈(10,)).& .!(hrs.wave.∈((10,11),)),
            tr_rows=(.!(hrs.wave_hosp.∈((10,11),)).& .!(hrs.wave.∈((10,11),)))), false)
    end

    @testset "StatsStep" begin
        @test sprint(show, CheckVars()) == "CheckVars"
        @test sprint(show, MIME("text/plain"), CheckVars()) ==
            "CheckVars (StatsStep that calls DiffinDiffsBase.checkvars)"

        @test _f(CheckVars()) == checkvars
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
