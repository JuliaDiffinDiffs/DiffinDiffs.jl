using DiffinDiffsBase: _f, _specnames, _tracenames

@testset "check_data" begin
    @testset "StatsStep" begin
        @test sprint(show, CheckData()) == """
        StatsStep: CheckData
          arguments from StatsSpec: (:data, :tr, :pr, :yterm, :treatname, :xterms, :weights, :subset)
          arguments from trace: ()"""
        @test sprintcompact(CheckData()) == "CheckData"

        @test _f(CheckData()) == check_data
        @test _specnames(CheckData()) == (:data, :tr, :pr, :yterm, :treatname, :xterms, :weights, :subset)
        @test _tracenames(CheckData()) == ()
    end
end 
