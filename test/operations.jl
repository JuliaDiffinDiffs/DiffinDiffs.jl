@testset "findcell" begin
    hrs = exampledata("hrs")
    @test_throws ArgumentError findcell((), hrs)
    @test_throws ArgumentError findcell((:wave,), hrs, falses(size(hrs, 1)))

    rows = findcell((:wave,), hrs)
    @test length(rows) == 5
    @test rows[UInt32(5)] == findall(x->x==7, hrs.wave)

    df = DataFrame(hrs)
    df.wave = PooledArray(df.wave)
    @test findcell((:wave,), df) == rows

    esample = hrs.wave.!=11
    rows = findcell((:wave, :wave_hosp), hrs, esample)
    @test length(rows) == 16
    @test rows[one(UInt32)] == intersect(findall(x->x==10, view(hrs.wave, esample)), findall(x->x==10, view(hrs.wave_hosp, esample)))

    rows = findcell((:wave, :wave_hosp, :male), hrs)
    @test length(rows) == 40
end

@testset "cellrows" begin
    hrs = exampledata("hrs")
    cols0 = subcolumns(hrs, (:wave, :wave_hosp), falses(size(hrs, 1)))
    cols = subcolumns(hrs, (:wave, :wave_hosp))
    rows_dict0 = IdDict{UInt32, Vector{Int}}()
    @test_throws ArgumentError cellrows(cols, rows_dict0)
    rows_dict = findcell(cols)
    @test_throws ArgumentError cellrows(cols0, rows_dict)

    cells, rows = cellrows(cols, rows_dict)
    @test length(cells[1]) == length(rows) == 20
    @test Tables.matrix(cells) ==
        sortslices(unique(hcat(hrs.wave, hrs.wave_hosp), dims=1), dims=1)
    @test propertynames(cells) == [:wave, :wave_hosp]
    @test rows[1] == intersect(findall(x->x==7, hrs.wave), findall(x->x==8, hrs.wave_hosp))
end

@testset "settime" begin
    hrs = exampledata("hrs")
    t = settime(hrs, :wave, step=2, reftype=Int16)
    @test eltype(refarray(t)) == Int16
    @test sort!(unique(refarray(t))) == 1:3
    t = settime(hrs, :wave, rotation=isodd.(hrs.wave))
    @test eltype(t) == eltype(hrs.wave)
    @test eltype(refarray(t)) == RotatingTimeValue{Bool, Int32}
    @test all(x->x.rotation==isodd(x.time), t.refs)
end

@testset "PanelStructure" begin
    hrs = exampledata("hrs")
    N = size(hrs, 1)
    panel = setpanel(hrs, :hhidpn, :wave)
    @test length(unique(panel.refs)) == N
    inidbounds = view(hrs.hhidpn, 2:N) .== view(hrs.hhidpn, 1:N-1)
    @test view(diff(panel.refs), inidbounds) == view(diff(hrs.wave), inidbounds)
    @test length(panel.idpool) == 656
    @test panel.timepool == 7:11

    panel1 = setpanel(hrs, :hhidpn, :wave, step=0.5, reftype=Int)
    @test view(diff(panel1.refs), inidbounds) == 2 .* view(diff(hrs.wave), inidbounds)
    @test panel1.timepool == 7.0:0.5:11.0
    @test eltype(panel1.refs) == Int

    @test_throws ArgumentError setpanel(hrs, :hhidpn, :oop_spend)
    @test_throws DimensionMismatch setpanel(hrs.hhidpn, 1:100)

    @test sprint(show, panel) == "Panel Structure"
    t = VERSION < v"1.6.0" ? "Array{Int64,1}" : " Vector{Int64}"
    @test sprint(show, MIME("text/plain"), panel) == """
        Panel Structure:
          idpool:   [1, 2, 3, 4, 5, 6, 7, 8, 9, 10  …  647, 648, 649, 650, 651, 652, 653, 654, 655, 656]
          timepool:   7:1:11
          laginds:  Dict{Int64,$t}()"""

    lags = findlag!(panel)
    @test sprint(show, MIME("text/plain"), panel) == """
        Panel Structure:
          idpool:   [1, 2, 3, 4, 5, 6, 7, 8, 9, 10  …  647, 648, 649, 650, 651, 652, 653, 654, 655, 656]
          timepool:   7:1:11
          laginds:  Dict(1 => [4, 5, 1, 2, 0, 7, 0, 10, 8, 6  …  0, 3275, 3271, 3273, 3274, 3279, 3280, 3277, 3278, 0])"""

    leads = findlead!(panel, -1)
    @test leads == leads
    @test_throws ArgumentError findlag!(panel, 5)

    @test ilag!(panel) === panel.laginds[1]
    @test ilag!(panel, 2) === panel.laginds[2]
    @test ilead!(panel) === panel.laginds[-1]

    l1 = lag(panel, hrs.wave)
    @test view(l1, hrs.wave.!=7) == view(hrs.wave, hrs.wave.!=7) .- 1
    @test all(ismissing, view(l1, hrs.wave.==7))
    l2 = lag(panel, hrs.wave, 2, default=-1)
    @test view(l2, hrs.wave.>=9) == view(hrs.wave, hrs.wave.>=9) .- 2
    @test all(x->x==-1, view(l2, hrs.wave.<9))
    @test eltype(l2) == Int
    l_2 = lead(panel, hrs.wave, 2, default=-1.0)
    @test view(l_2, hrs.wave.<=9) == view(hrs.wave, hrs.wave.<=9) .+ 2
    @test all(x->x==-1, view(l_2, hrs.wave.>9))
    @test eltype(l_2) == Int

    @test_throws DimensionMismatch lag(panel, 1:10)

    d1 = diff(panel, hrs.wave)
    @test all(x->x==1, view(d1, hrs.wave.!=7))
    @test all(ismissing, view(d1, hrs.wave.==7))
    d2 = diff(panel, hrs.wave, l=2, default=-1)
    @test all(x->x==2, view(d2, hrs.wave.>=9))
    @test all(x->x==-1, view(d2, hrs.wave.<9))
    @test eltype(d2) == Int
    d_2 = diff(panel, hrs.wave, l=-2, default=-1.0)
    @test all(x->x==-2, view(d_2, hrs.wave.<=9))
    @test all(x->x==-1, view(d_2, hrs.wave.>9))
    @test eltype(d_2) == Int
    
    d2 = diff(panel, hrs.wave, order=2)
    @test all(x->x==0, view(d2, hrs.wave.>=9))
    @test all(ismissing, view(d2, hrs.wave.<9))
    d2 = diff(panel, hrs.wave, order=2, l=2)
    @test all(x->x==0, view(d2, hrs.wave.==11))
    @test all(ismissing, view(d2, hrs.wave.!=11))

    @test_throws ArgumentError diff(panel, hrs.wave, l=5)
    @test_throws ArgumentError diff(panel, hrs.wave, order=5)
end
