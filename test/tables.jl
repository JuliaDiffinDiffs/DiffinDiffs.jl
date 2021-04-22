@testset "VecColumnTable" begin
    hrs = exampledata("hrs")
    cols = VecColumnTable(AbstractVector[], Symbol[], Dict{Symbol,Int}())
    cols1 = VecColumnTable(AbstractVector[], Symbol[])
    @test cols1 == cols
    cols2 = VecColumnTable(cols1)
    @test cols2 === cols1
    cols3 = VecColumnTable(DataFrame())
    @test cols3 == cols
    @test size(cols) == (0, 0)
    @test length(cols) == 0
    @test isempty(cols)
    @test_throws BoundsError cols[1]
    @test_throws ArgumentError size(cols, 3)
    @test sprint(show, MIME("text/plain"), cols) == "0×0 VecColumnTable"

    cols = VecColumnTable(AbstractVector[[]], Symbol[:a], Dict{Symbol,Int}(:a=>1))
    @test size(cols) == (0, 1)
    @test length(cols) == 1
    @test isempty(cols)
    @test sprint(show, MIME("text/plain"), cols) == "0×1 VecColumnTable"

    cols = VecColumnTable((wave=hrs.wave,))
    @test size(cols) == (3280, 1)
    rows = collect(Tables.rows(cols))
    @test hash(rows[2]) == hash(rows[6])
    @test isequal(rows[2], rows[6])
    @test !isequal(rows[1], rows[2])
    @test isless(rows[1], rows[3])
    @test !isless(rows[1], rows[2])

    cols = VecColumnTable(AbstractVector[hrs.wave, hrs.oop_spend], [:wave, :oop_spend],
        Dict(:wave=>1, :oop_spend=>2))
    cols1 = VecColumnTable(AbstractVector[hrs.wave, hrs.oop_spend], [:wave, :oop_spend])
    @test cols1 == cols
    @test nrow(cols) == 3280
    @test ncol(cols) == 2
    @test size(cols) == (3280, 2)
    @test length(cols) == 2
    @test isempty(cols) === false

    cols2 = VecColumnTable(hrs)
    @test size(cols2) == (3280, 11)
    cols3 = VecColumnTable(cols2)
    @test cols3 === cols2
    esample = hrs.wave.==7
    cols3 = VecColumnTable(hrs, esample)
    @test size(cols3) == (sum(esample), 11)
    cols4 = VecColumnTable(cols2, esample)
    @test cols4 == cols3

    @test VecColumnTable(cols2, :) == view(cols2, :) == cols2
    @test VecColumnTable(cols2, 1:3280) == view(cols2, 1:3280) == cols2
    @test VecColumnTable(cols2, [2,1]) == view(cols2, [2,1])

    @test cols[1] === hrs.wave
    @test cols[:] == cols[1:2] == cols[[1,2]] == cols[trues(2)] == [hrs.wave, hrs.oop_spend]
    @test cols[:wave] === cols[1]
    @test cols[[:oop_spend, :wave]] == [hrs.oop_spend, hrs.wave]
    @test_throws ArgumentError cols[[1, :oop_spend]]
    @test_throws BoundsError cols[1:3]

    @test propertynames(cols) == [:wave, :oop_spend]
    @test cols.wave === cols[1]

    @test keys(cols) == [:wave, :oop_spend]
    @test values(cols) == [hrs.wave, hrs.oop_spend]
    @test haskey(cols, :wave)
    @test haskey(cols, 1)
    @test get(cols, :wave, nothing) == cols[1]
    @test get(cols, :none, nothing) === nothing

    @test [col for col in cols] == cols[:]

    @test cols == deepcopy(cols)

    @test sprint(show, cols) == "3280×2 VecColumnTable"
    @test sprint(show, MIME("text/plain"), cols, context=:displaysize=>(18,80)) == """
        3280×2 VecColumnTable:
          Row │  wave  oop_spend
              │ Int64    Float64
        ──────┼──────────────────
            1 │    10    6532.91
            2 │     8    1326.93
            3 │    11    1050.33
            4 │     9    979.418
            5 │     7    5498.68
          ⋮   │   ⋮        ⋮
         3276 │    11    3020.78
         3277 │     8     2632.0
         3278 │     9     657.34
         3279 │    10    782.795
         3280 │     7    4182.39"""

    @test summary(cols) == "3280×2 VecColumnTable"
    @test sprint(summary, cols) == "3280×2 VecColumnTable"

    @test Tables.istable(typeof(cols))
    @test Tables.columnaccess(typeof(cols))
    @test Tables.columns(cols) === cols
    @test Tables.getcolumn(cols, 1) === cols[1]
    @test Tables.getcolumn(cols, :wave) === cols[1]
    @test Tables.columnnames(cols) == [:wave, :oop_spend]

    @test Tables.schema(cols) == Tables.Schema{(:wave, :oop_spend), Tuple{Int, Float64}}()
    @test Tables.materializer(cols) == VecColumnTable

    @test Tables.columnindex(cols, :wave) == 1
    @test Tables.columntype(cols, :wave) == Int
    @test Tables.rowcount(cols) == 3280

    @test eltype(Tables.rows(cols)) == VecColsRow
    rows0 = collect(Tables.rows(cols))
    @test ncol(rows0[1]) == 2
    @test hash(rows0[2]) != hash(rows0[6])
    @test isequal(rows0[1], rows0[1])
    @test isequal(rows0[1], rows0[2]) == false
    @test isless(rows0[2], rows0[1])

    # Same data but different parent tables
    rows1 = collect(Tables.rows(cols1))
    @test hash(rows0[1]) == hash(rows1[1])
    @test isequal(rows0[1], rows1[1])
    @test isless(rows0[2], rows1[1])

    # Rows do not have the same length
    @test !isequal(rows[1], rows0[1])
    @test_throws ArgumentError isless(rows[1], rows0[1])

    cols2 = VecColumnTable((wave=hrs.wave, male=hrs.male))
    rows2 = collect(Tables.rows(cols2))
    @test hash(rows2[2]) == hash(rows2[6])
    @test isequal(rows2[2], rows2[6])

    # Different column names but otherwise the same table
    cols3 = VecColumnTable((wave1=hrs.wave, oop_spend1=hrs.oop_spend))
    rows3 = collect(Tables.rows(cols3))
    @test hash(rows0[2]) == hash(rows3[2])
    @test isequal(rows0[2], rows3[2])
    @test isless(rows0[2], rows3[1])

    df = DataFrame(hrs)
    @test sortperm(cols) == sortperm(rows0) == sortperm(df, [:wave, :oop_spend])
    cols_sorted = sort(cols)
    df_sorted = sort(df, [:wave, :oop_spend])
    @test cols_sorted.oop_spend == df_sorted.oop_spend
    sort!(cols)
    @test cols.oop_spend == df_sorted.oop_spend
end
    
@testset "subcolumns" begin
    hrs = exampledata("hrs")
    df = DataFrame(hrs)
    allowmissing!(df)

    cols = subcolumns(df, [])
    @test size(cols) == (0, 0)
    @test isempty(cols)

    cols = subcolumns(df, :wave, falses(size(df,1)))
    @test size(cols) == (0, 1)
    @test isempty(cols)
    @test cols.wave == cols[:wave] == cols[1] == Int[]

    cols = subcolumns(df, :wave)
    @test cols.wave == hrs.wave
    @test eltype(cols.wave) == Int
    @test size(cols) == (3280, 1)

    cols = subcolumns(df, :wave, nomissing=false)
    @test cols.wave == hrs.wave
    @test eltype(cols.wave) == Union{Int, Missing}

    df.male .= ifelse.(df.wave.==11, missing, df.male)
    @test_throws MethodError subcolumns(df, :male)

    cols = subcolumns(df, :male, df.wave.!=11)
    @test cols.male == hrs.male[hrs.wave.!=11]
    @test eltype(cols.male) == Int

    cols = subcolumns(df, (:wave, :male), df.wave.!=11)
    @test cols.wave == hrs.wave[hrs.wave.!=11]
    @test eltype(cols.wave) == Int
    @test subcolumns(df, [:wave, :male], df.wave.!=11) == cols
end

@testset "apply apply_and" begin
    cols = VecColumnTable((a=collect(1:10), b=collect(2:11)))
    @test apply(cols, :a=>identity) == cols.a
    @test apply(cols, 2=>identity) == cols.b
    @test apply(cols, (:a,2)=>(x,y)->x+y) == cols.a .+ cols.b
    @test apply(cols, :a=>identity, :b=>identity) == cols.a

    inds = trues(10)
    apply_and!(inds, cols, :a=>isodd)
    @test inds == isodd.(cols.a)
    inds = trues(10)
    apply_and!(inds, cols, [1,:b]=>(x,y)->isodd(x)&&isodd(y))
    @test inds == falses(10)
    inds = trues(10)
    apply_and!(inds, cols, :a=>isodd, :a=>isodd)
    @test inds == isodd.(cols.a)
    inds = trues(10)
    apply_and!(inds, cols, :a=>isodd, :b=>isodd)
    @test inds == falses(10)

    @test apply_and(cols, :a=>isodd) == isodd.(cols.a)
    @test apply_and(cols, :a=>isodd, :b=>isodd) == falses(10)
end

@testset "TableIndexedMatrix" begin
    m = reshape(1:100, 10, 10)
    r = VecColumnTable((a=collect(1:10),))
    c = VecColumnTable((b=collect(1:10),))
    tm = TableIndexedMatrix(m, r, c)
    @test size(tm) == size(m)
    @test tm[1] == 1
    @test tm[1, 1] == 1
    @test IndexStyle(tm) == IndexLinear()

    @test_throws ArgumentError TableIndexedMatrix(m, 1:10, c)
    r1 = VecColumnTable((a=collect(1:11),))
    @test_throws DimensionMismatch TableIndexedMatrix(m, r1, c)
end
