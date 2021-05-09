@testset "CheckData" begin
    @testset "checkdata!" begin
        hrs = exampledata("hrs")
        nt = (data=hrs, subset=nothing, weightname=nothing)
        ret = checkdata!(nt...)
        @test ret.esample == trues(size(hrs,1))

        nt = merge(nt, (weightname=:rwthh, subset=hrs.male.==1))
        ret = checkdata!(nt...)
        @test ret.esample == BitArray(hrs.male)

        df = DataFrame(hrs)
        allowmissing!(df, :rwthh)
        df.rwthh[1] = missing
        nt = merge(nt, (data=df, subset=nothing))
        ret = checkdata!(nt...)
        @test ret.esample == (hrs.rwthh.>0) .& (.!ismissing.(df.rwthh))

        nt = merge(nt, (data=rand(10,10),))
        @test_throws ArgumentError checkdata!(nt...)
        nt = merge(nt, (data=[(a=1, b=2), (a=1, b=2)],))
        @test_throws ArgumentError checkdata!(nt...)
        nt = merge(nt, (data=hrs, subset=BitArray(hrs.male[1:100])))
        @test_throws DimensionMismatch checkdata!(nt...)
        nt = merge(nt, (subset=falses(size(hrs,1)),))
        @test_throws ErrorException checkdata!(nt...)
    end

    @testset "StatsStep" begin
        @test sprint(show, CheckData()) == "CheckData"
        @test sprint(show, MIME("text/plain"), CheckData()) ==
            "CheckData (StatsStep that calls DiffinDiffsBase.checkdata!)"

        @test _f(CheckData()) == checkdata!

        hrs = exampledata("hrs")
        nt = (data=hrs, subset=nothing, weightname=nothing)
        ret = CheckData()(nt)
        @test ret.esample == trues(size(hrs,1))
        @test ret.aux isa BitVector
        @test_throws ErrorException CheckData()()
    end
end

@testset "GroupTerms" begin
    @testset "groupterms" begin
        nt = (treatintterms=TermSet(), xterms=TermSet(term(:x)))
        @test groupterms(nt...) == nt
    end

    @testset "StatsStep" begin
        @test sprint(show, GroupTerms()) == "GroupTerms"
        @test sprint(show, MIME("text/plain"), GroupTerms()) ==
            "GroupTerms (StatsStep that calls DiffinDiffsBase.groupterms)"
        @test _byid(GroupTerms()) == false
        nt = (treatintterms=TermSet(), xterms=TermSet(term(:x)))
        @test GroupTerms()(nt) == nt 
    end
end

@testset "CheckVars" begin
    @testset "checkvars!" begin
        hrs = exampledata("hrs")
        N = size(hrs,1)
        nt = (data=hrs, tr=dynamic(:wave, -1), pr=nevertreated(11), yterm=term(:oop_spend),
            treatname=:wave_hosp, esample=trues(N), aux=BitVector(undef, N),
            treatintterms=TermSet(), xterms=TermSet())
        @test checkvars!(nt...) == (esample=trues(N), tr_rows=hrs.wave_hosp.!=11)

        nt = merge(nt, (pr=notyettreated(11),))
        @test checkvars!(nt...) == (esample=hrs.wave.!=11,
            tr_rows=(hrs.wave_hosp.!=11).&(hrs.wave.!=11))

        nt = merge(nt, (pr=notyettreated(11, 10), esample=trues(N)))
        @test checkvars!(nt...) ==
            (esample=.!(hrs.wave_hosp.∈(10,)).& .!(hrs.wave.∈((10,11),)),
            tr_rows=(.!(hrs.wave_hosp.∈((10,11),)).& .!(hrs.wave.∈((10,11),))))

        nt = merge(nt, (pr=nevertreated(11), treatintterms=TermSet(term(:male)),
            xterms=TermSet(term(:white)), esample=trues(N)))
        @test checkvars!(nt...) == (esample=trues(N), tr_rows=hrs.wave_hosp.!=11)

        df = DataFrame(hrs)
        allowmissing!(df, :male)
        df.male .= ifelse.(df.wave_hosp.==11, missing, df.male)
        nt = merge(nt, (data=df,))
        @test checkvars!(nt...) == (esample=trues(N), tr_rows=hrs.wave_hosp.!=11)
        df.male .= ifelse.(df.wave_hosp.==10, missing, df.male)
        @test checkvars!(nt...) == (esample=df.wave_hosp.!=10, tr_rows=hrs.wave_hosp.∈((8,9),))
        df.white = ifelse.(df.wave_hosp.==9, missing, df.white.+0.5)
        ret = (esample=df.wave_hosp.∈((8,11),), tr_rows=hrs.wave_hosp.==8)
        @test checkvars!(nt...) == ret

        df.wave_hosp = Date.(df.wave_hosp)
        @test_throws ArgumentError checkvars!(nt...)
        df.wave = Date.(df.wave)
        @test_throws ArgumentError checkvars!(nt...)
        nt = merge(nt, (pr=nevertreated(Date(11)),))
        @test_throws ArgumentError checkvars!(nt...)
        df.wave = settime(df.wave, step=Year(1))
        df.wave_hosp = settime(df.wave_hosp, step=Year(1))
        @test_throws ArgumentError checkvars!(nt...)
        df.wave_hosp = aligntime(df, :wave_hosp, :wave)
        @test checkvars!(nt...) == ret
        nt = merge(nt, (pr=notyettreated(Date(11)),esample=trues(N)))
        ret = checkvars!(nt...)
        @test ret == (esample=(df.wave_hosp.∈((Date(8),Date(11)),)).&(df.wave.!=Date(11)),
            tr_rows=(df.wave_hosp.==Date(8)).&(df.wave.!=Date(11)))

        allowmissing!(df, :wave)
        df.wave .= ifelse.((df.wave_hosp.==Date(8)).&(df.wave.∈((Date(7), Date(8)),)),
            missing, df.wave)
        nt = merge(nt, (esample=trues(N), pr=nevertreated(Date(11))))
        ret = checkvars!(nt...)
        @test ret.esample == (df.wave_hosp.∈((Date(8),Date(11)),)).& (.!(hrs.wave.∈((7,8),)))
        @test ret.tr_rows == ret.esample.&(df.wave_hosp.!=Date(11))
        nt = merge(nt, (esample=trues(N), pr=notyettreated(Date(11))))
        ret = checkvars!(nt...)
        @test ret.esample == (df.wave_hosp.∈((Date(8),Date(11)),)).& (hrs.wave.∈((9,10),))
        @test ret.tr_rows == ret.esample.&(df.wave_hosp.!=Date(11))

        df = DataFrame(hrs)
        rot = ifelse.(isodd.(df.hhidpn), 1, 2)
        df.wave_hosp = rotatingtime(rot, df.wave_hosp)
        df.wave = rotatingtime(rot, df.wave)
        e = rotatingtime((1,2), 11)
        nt = merge(nt, (data=df, tr=dynamic(:wave, -1), pr=nevertreated(e), treatintterms=TermSet(), xterms=TermSet(), esample=trues(N)))
        ret1 = checkvars!(nt...)
        @test ret1 == (esample=trues(N), tr_rows=hrs.wave_hosp.!=11)
        df.wave_hosp = rotatingtime(2, hrs.wave_hosp)
        df.wave = rotatingtime(2, hrs.wave)
        nt = merge(nt, (esample=trues(N), pr=notyettreated(e),))
        ret2 = checkvars!(nt...)
        @test ret2 == (esample=hrs.wave.!=11, tr_rows=(hrs.wave_hosp.!=11).&(hrs.wave.!=11))

        df.wave = settime(Date.(hrs.wave), step=Year(1), rotation=rot)
        df.wave_hosp = rotatingtime(rot, Date.(hrs.wave_hosp))
        df.wave_hosp = aligntime(df, :wave_hosp, :wave)
        e = rotatingtime((1,2), Date(11))
        nt = merge(nt, (esample=trues(N), pr=nevertreated(e)))
        @test checkvars!(nt...) == ret1
        nt = merge(nt, (esample=trues(N), pr=notyettreated(e),))
        @test checkvars!(nt...) == ret2

        allowmissing!(df, :wave_hosp)
        df.wave_hosp .= ifelse.(hrs.wave_hosp.==8, missing, df.wave_hosp)
        nt = merge(nt, (esample=trues(N), pr=nevertreated(e)))
        ret = checkvars!(nt...)
        @test ret.esample == (hrs.wave_hosp.!=8)
        @test ret.tr_rows == ret.esample.&(hrs.wave_hosp.!=11)
        nt = merge(nt, (esample=trues(N), pr=notyettreated(e)))
        ret = checkvars!(nt...)
        @test ret.esample == (hrs.wave_hosp.!=8).&(hrs.wave.!=11)
        @test ret.tr_rows == ret.esample.&(hrs.wave_hosp.!=11)
    end

    @testset "StatsStep" begin
        @test sprint(show, CheckVars()) == "CheckVars"
        @test sprint(show, MIME("text/plain"), CheckVars()) ==
            "CheckVars (StatsStep that calls DiffinDiffsBase.checkvars!)"

        @test _f(CheckVars()) == checkvars!

        hrs = exampledata("hrs")
        N = size(hrs,1)
        nt = (data=hrs, tr=dynamic(:wave, -1), pr=nevertreated(11), yterm=term(:oop_spend),
            treatname=:wave_hosp, treatintterms=TermSet(), xterms=TermSet(),
            esample=trues(N), aux=BitVector(undef, N))
        gargs = groupargs(CheckVars(), nt)
        @test gargs[copyargs(CheckVars())...] == nt.esample

        @test CheckVars()(nt) ==
            merge(nt, (esample=trues(N), tr_rows=hrs.wave_hosp.!=11))
        nt = (data=hrs, tr=dynamic(:wave, -1), pr=nevertreated(11), yterm=term(:oop_spend),
            treatname=:wave_hosp, esample=trues(N), aux=BitVector(undef, N))
        @test CheckVars()(nt) ==
            merge(nt, (esample=trues(N), tr_rows=hrs.wave_hosp.!=11))
        @test_throws ErrorException CheckVars()()
    end
end

@testset "MakeWeights" begin
    @testset "makeweights" begin
        hrs = exampledata("hrs")
        nt = (data=hrs, esample=trues(size(hrs,1)), weightname=nothing)
        r = makeweights(nt...)
        @test r.weights isa UnitWeights && sum(r.weights) == size(hrs,1)

        nt = merge(nt, (weightname=:rwthh,))
        r = makeweights(nt...)
        @test r.weights isa Weights && sum(r.weights) == sum(hrs.rwthh)
    end

    @testset "StatsStep" begin
        @test sprint(show, MakeWeights()) == "MakeWeights"
        @test sprint(show, MIME("text/plain"), MakeWeights()) ==
            "MakeWeights (StatsStep that calls DiffinDiffsBase.makeweights)"

        @test _f(MakeWeights()) == makeweights

        hrs = exampledata("hrs")
        nt = (data=hrs, esample=trues(size(hrs,1)))
        r = MakeWeights()(nt)
        @test r.weights isa UnitWeights && sum(r.weights) == size(hrs,1)
    end
end
