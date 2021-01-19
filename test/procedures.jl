using DiffinDiffsBase: _f, _specnames, _tracenames, checkdata

@testset "CheckData" begin
    @testset "StatsStep" begin
        @test sprint(show, CheckData()) == "CheckData"
        @test sprint(show, MIME("text/plain"), CheckData()) == """
        CheckData (StatsStep that calls DiffinDiffsBase.checkdata):
          arguments from StatsSpec: (:data, :tr, :pr, :yterm, :treatname, :xterms, :weights, :subset)
          arguments from trace: ()"""

        @test _f(CheckData()) == checkdata
        @test _specnames(CheckData()) == (:data, :tr, :pr, :yterm, :treatname, :xterms, :weights, :subset)
        @test _tracenames(CheckData()) == ()
    end

    @testset "checkdata" begin
        hrs = exampledata("hrs")
        nt = (data=hrs, tr=dynamic(:wave, -1), pr=nevertreated(11),
            yterm=term(:oop_spend), treatname=:wave_hosp, xterms=(),
            weights=nothing, subset=nothing)
        @test checkdata(nt...) ==
            (vars=[:wave_hosp, :wave, :oop_spend], esample=trues(size(hrs,1)))
        
        nt = merge(nt, (weights=:rwthh, subset=hrs.male))
        @test checkdata(nt...) ==
            (vars=[:wave_hosp, :wave, :oop_spend], esample=BitArray(hrs.male))
        
        nt = merge(nt, (data=rand(10,10),))
        @test_throws ArgumentError checkdata(nt...)

        nt = merge(nt, (data=hrs, subset=BitArray(hrs.male[1:100])))
        @test_throws DimensionMismatch checkdata(nt...)

        nt = merge(nt, (subset=falses(size(hrs,1)),))
        @test_throws ErrorException checkdata(nt...)
    end
end 
