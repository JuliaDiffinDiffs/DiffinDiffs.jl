using DiffinDiffsBase: _f, _specnames, _tracenames,
    check_data

@testset "check_data" begin
    @testset "StatsStep" begin
        @test sprint(show, CheckData()) == "CheckData"
        @test sprint(show, MIME("text/plain"), CheckData()) == """
        CheckData (StatsStep that calls DiffinDiffsBase.check_data):
          arguments from StatsSpec: (:data, :tr, :pr, :yterm, :treatname, :xterms, :weights, :subset)
          arguments from trace: ()"""

        @test _f(CheckData()) == check_data
        @test _specnames(CheckData()) == (:data, :tr, :pr, :yterm, :treatname, :xterms, :weights, :subset)
        @test _tracenames(CheckData()) == ()
    end
end 
