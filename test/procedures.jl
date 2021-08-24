@testset "CheckData" begin
    @testset "checkdata!" begin
        hrs = exampledata("hrs")
        nt = (data=hrs, subset=nothing, weightname=nothing)
        ret = checkdata!(nt...)
        @test ret.esample == trues(size(hrs,1))

        ismale = hrs.male.==1
        nt = merge(nt, (weightname=:rwthh, subset=ismale))
        ret = checkdata!(nt...)
        @test ret.esample == ismale
        @test ret.esample !== ismale

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

@testset "GroupTreatintterms" begin
    @testset "grouptreatintterms" begin
        nt = (treatintterms=TermSet(),)
        @test grouptreatintterms(nt...) == nt
    end

    @testset "StatsStep" begin
        @test sprint(show, GroupTreatintterms()) == "GroupTreatintterms"
        @test sprint(show, MIME("text/plain"), GroupTreatintterms()) ==
            "GroupTreatintterms (StatsStep that calls DiffinDiffsBase.grouptreatintterms)"
        @test _byid(GroupTreatintterms()) == false
        nt = (treatintterms=TermSet(),)
        @test GroupTreatintterms()() == nt
    end
end

@testset "GroupXterms" begin
    @testset "groupxterms" begin
        nt = (xterms=TermSet(term(:x)),)
        @test groupxterms(nt...) == nt
    end

    @testset "StatsStep" begin
        @test sprint(show, GroupXterms()) == "GroupXterms"
        @test sprint(show, MIME("text/plain"), GroupXterms()) ==
            "GroupXterms (StatsStep that calls DiffinDiffsBase.groupxterms)"
        @test _byid(GroupXterms()) == false
        nt = (xterms=TermSet(),)
        @test GroupXterms()() == nt
    end
end

@testset "GroupContrasts" begin
    @testset "groupcontrasts" begin
        nt = (contrasts=Dict{Symbol,Any}(),)
        @test groupcontrasts(nt...) == nt
    end

    @testset "StatsStep" begin
        @test sprint(show, GroupContrasts()) == "GroupContrasts"
        @test sprint(show, MIME("text/plain"), GroupContrasts()) ==
            "GroupContrasts (StatsStep that calls DiffinDiffsBase.groupcontrasts)"
        @test _byid(GroupContrasts()) == false
        nt = (contrasts=nothing,)
        @test GroupContrasts()() == nt
    end
end

@testset "CheckVars" begin
    @testset "checkvars!" begin
        hrs = exampledata("hrs")
        N = size(hrs,1)
        us = unspecifiedpr()
        tr = dynamic(:wave, -1)
        nt = (data=hrs, pr=us, yterm=term(:oop_spend),
            treatname=:wave_hosp, esample=trues(N), aux=BitVector(undef, N),
            treatintterms=TermSet(), xterms=TermSet(),
            tytr=typeof(tr), trvars=(termvars(tr)...,), tr=tr)
        @test checkvars!(nt...) == (esample=trues(N), tr_rows=trues(N))

        nt = merge(nt, (pr=nevertreated(11),))
        @test checkvars!(nt...) == (esample=trues(N), tr_rows=hrs.wave_hosp.!=11)

        nt = merge(nt, (pr=notyettreated(11),))
        @test checkvars!(nt...) == (esample=hrs.wave.!=11,
            tr_rows=(hrs.wave_hosp.!=11).&(hrs.wave.!=11))

        nt = merge(nt, (pr=notyettreated(11, 10), esample=trues(N)))
        @test checkvars!(nt...) ==
            (esample=.!(hrs.wave_hosp.∈(10,)).& .!(hrs.wave.∈((10,11),)),
            tr_rows=(.!(hrs.wave_hosp.∈((10,11),)).& .!(hrs.wave.∈((10,11),))))

        nt = merge(nt, (pr=notyettreated(10),
            esample=.!((hrs.wave_hosp.==10).&(hrs.wave.==9))))
        @test checkvars!(nt...) == (esample=(hrs.wave.<9).&(hrs.wave_hosp.<=10),
            tr_rows=(hrs.wave.<9).&(hrs.wave_hosp.<=9))

        nt = merge(nt, (pr=us, treatintterms=TermSet(term(:male)),
            xterms=TermSet(term(:white)), esample=trues(N)))
        @test checkvars!(nt...) == (esample=trues(N), tr_rows=trues(N))

        nt = merge(nt, (pr=nevertreated(11), treatintterms=TermSet(term(:male)),
            xterms=TermSet(term(:white)), esample=trues(N)))
        @test checkvars!(nt...) == (esample=trues(N), tr_rows=hrs.wave_hosp.!=11)

        df = DataFrame(hrs)
        allowmissing!(df, :male)
        df.male .= ifelse.(hrs.wave_hosp.==11, missing, df.male)

        nt = merge(nt, (data=df, pr=us, esample=trues(N)))
        @test checkvars!(nt...) == (esample=hrs.wave_hosp.!=11, tr_rows=hrs.wave_hosp.!=11)
        df.male .= ifelse.(hrs.wave_hosp.==10, missing, hrs.male)
        nt = merge(nt, (esample=trues(N),))
        @test checkvars!(nt...) == (esample=hrs.wave_hosp.!=10, tr_rows=hrs.wave_hosp.!=10)

        df.male .= ifelse.(hrs.wave_hosp.==11, missing, hrs.male)
        nt = merge(nt, (pr=nevertreated(11), esample=trues(N)))
        @test checkvars!(nt...) == (esample=trues(N), tr_rows=hrs.wave_hosp.!=11)
        df.male .= ifelse.(hrs.wave_hosp.==10, missing, df.male)
        @test checkvars!(nt...) == (esample=hrs.wave_hosp.!=10, tr_rows=hrs.wave_hosp.∈((8,9),))
        df.white = ifelse.(hrs.wave_hosp.==9, missing, df.white.+0.5)
        ret = (esample=hrs.wave_hosp.∈((8,11),), tr_rows=hrs.wave_hosp.==8)
        @test checkvars!(nt...) == ret

        df.wave_hosp = Date.(df.wave_hosp)
        @test_throws ArgumentError checkvars!(nt...)
        df.wave = Date.(df.wave)
        @test_throws ArgumentError checkvars!(nt...)
        nt = merge(nt, (pr=nevertreated(Date(11)),))
        @test_throws ArgumentError checkvars!(nt...)
        df.wave = settime(df.wave, Year(1))
        df.wave_hosp = settime(df.wave_hosp, Year(1))
        @test_throws ArgumentError checkvars!(nt...)
        df.wave_hosp = aligntime(df, :wave_hosp, :wave)
        @test checkvars!(nt...) == ret
        nt = merge(nt, (pr=notyettreated(Date(11)), esample=trues(N)))
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
        nt = merge(nt, (data=df, pr=nevertreated(e), treatintterms=TermSet(),
            xterms=TermSet(), esample=trues(N)))
        # Check RotatingTimeArray
        @test_throws ArgumentError checkvars!(nt...)
        df.wave_hosp = settime(hrs.wave_hosp, rotation=rot)
        df.wave = settime(hrs.wave, rotation=rot)
        # Check aligntime
        @test_throws ArgumentError checkvars!(nt...)
        df.wave_hosp = aligntime(df.wave_hosp, df.wave)
        ret1 = checkvars!(nt...)
        @test ret1 == (esample=trues(N), tr_rows=hrs.wave_hosp.!=11)
        df.wave_hosp = settime(hrs.wave_hosp, start=7, rotation=ones(N))
        df.wave = settime(hrs.wave, rotation=ones(N))
        # Check the match of field type of pr.e
        @test_throws ArgumentError checkvars!(nt...)
        df.wave_hosp = settime(hrs.wave_hosp, start=7, rotation=ones(Int, N))
        df.wave = settime(hrs.wave, rotation=ones(Int, N))
        nt = merge(nt, (esample=trues(N), pr=notyettreated(e),))
        ret2 = checkvars!(nt...)
        @test ret2 == (esample=hrs.wave.!=11, tr_rows=(hrs.wave_hosp.!=11).&(hrs.wave.!=11))

        # RotatingTimeArray with time field of type Array
        df.wave_hosp = RotatingTimeArray(rot, hrs.wave_hosp)
        df.wave = RotatingTimeArray(rot, hrs.wave)
        e = rotatingtime((1,2), (10,11))
        nt = merge(nt, (esample=trues(N), pr=notyettreated(e)))
        ret3 = checkvars!(nt...)
        ret3e = (hrs.wave.!=11).&(.!((hrs.wave.==10).&(rot.==1))).&
            (.!((hrs.wave_hosp.==11).&(rot.==1)))
        @test ret3 == (esample=ret3e, tr_rows=ret3e.&
            (hrs.wave_hosp.!=11).&(.!((hrs.wave_hosp.==10).&(rot.==1))))

        df.wave = settime(Date.(hrs.wave), Year(1), rotation=rot)
        df.wave_hosp = settime(Date.(hrs.wave_hosp), Year(1), start=Date(7), rotation=rot)
        e = rotatingtime((1,2), Date(11))
        nt = merge(nt, (esample=trues(N), pr=nevertreated(e)))
        @test checkvars!(nt...) == ret1
        nt = merge(nt, (esample=trues(N), pr=notyettreated(e),))
        @test checkvars!(nt...) == ret2
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
            treatname=:wave_hosp, esample=trues(N), aux=BitVector(undef, N),
            treatintterms=TermSet(), xterms=TermSet())
        @test CheckVars()(nt) ==
            merge(nt, (esample=trues(N), tr_rows=hrs.wave_hosp.!=11))
        @test_throws ErrorException CheckVars()()
    end
end

@testset "GroupSample" begin
    @testset "groupsample" begin
        nt = (esample=trues(3),)
        @test groupsample(nt...) == nt
    end

    @testset "StatsStep" begin
        @test sprint(show, GroupSample()) == "GroupSample"
        @test sprint(show, MIME("text/plain"), GroupSample()) ==
            "GroupSample (StatsStep that calls DiffinDiffsBase.groupsample)"
        @test _byid(GroupSample()) == false
        nt = (esample=trues(3),)
        @test GroupSample()(nt) == nt
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
