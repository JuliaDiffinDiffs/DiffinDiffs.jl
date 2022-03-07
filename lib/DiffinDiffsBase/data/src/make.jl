# Generate example datasets as compressed CSV files

# See data/README.md for the sources of the input data files
# To regenerate the .csv.gz files:
# 1) Have all input files ready in the data folder
# 2) Instantiate the package environment for data/src
# 3) Run this script and call `make()` with the root folder as working directory

using CSV, CodecBzip2, CodecZlib, DataFrames, DataValues, RData, ReadStat

function _to_array(d::DataValueArray{T}) where T
    a = Array{T}(undef, size(d))
    hasmissing = false
    @inbounds for i in eachindex(d)
        v = d[i]
        if hasvalue(v)
            a[i] = v.value
        elseif !hasmissing
            a = convert(Array{Union{T,Missing}}, a)
            hasmissing = true
            a[i] = missing
        else
            a[i] = missing
        end
    end
    return a
end

function _get_columns(data::ReadStatDataFrame, names::Vector{Symbol})
    lookup = Dict(data.headers.=>keys(data.headers))
    cols = Vector{AbstractVector}(undef, length(names))
    for (i, n) in enumerate(names)
        col = data.data[lookup[n]]
        cols[i] = _to_array(col)
    end
    return cols
end

# The steps for preparing data follow Sun and Abraham (2020)
function hrs()
    raw = read_dta("data/HRS_long.dta")
    names = [:hhidpn, :wave, :wave_hosp, :evt_time, :oop_spend, :riearnsemp, :rwthh,
        :male, :spouse, :white, :black, :hispanic, :age_hosp]
    cols = _get_columns(raw, names)
    df = dropmissing!(DataFrame(cols, names), [:wave, :age_hosp, :evt_time])
    df = df[(df.wave.>=7).&(df.age_hosp.<=59), :]
    # Must count wave after the above selection
    transform!(groupby(df, :hhidpn), nrow=>:nwave, :evt_time => minimum => :evt_time)
    df = df[(df.nwave.==5).&(df.evt_time.<0), :]
    transform!(groupby(df, :hhidpn), :wave_hosp => minimum∘skipmissing => :wave_hosp)
    select!(df, Not([:nwave, :evt_time, :age_hosp]))
    for n in (:male, :spouse, :white, :black, :hispanic)
        df[!, n] .= ifelse.(df[!, n].==100, 1, 0)
    end
    for n in propertynames(df)
        if !(n in (:oop_spend, :riearnsemp, :wrthh))
            df[!, n] .= convert(Array{Int}, df[!, n])
        end
    end
    # Replace the original hh index with enumeration
    ids = IdDict{Int,Int}()
    hhidpn = df.hhidpn
    newid = 0
    for i in 1:length(hhidpn)
        oldid = hhidpn[i]
        id = get(ids, oldid, 0)
        if id === 0
            newid += 1
            ids[oldid] = newid
            hhidpn[i] = newid
        else
            hhidpn[i] = id
        end
    end
    open(GzipCompressorStream, "data/hrs.csv.gz", "w") do stream
        CSV.write(stream, df)
    end
end

# Produce a subset of nsw_long from the DRDID R package
function nsw()
    df = DataFrame(CSV.File("data/ec675_nsw.tab", delim='\t'))
    df = df[(isequal.(df.treated, 0)).|(df.sample.==2), Not([:dwincl, :early_ra])]
    df.experimental = ifelse.(ismissing.(df.treated), 0, 1)
    select!(df, Not([:treated, :sample]))
    df.id = 1:nrow(df)
    # Convert the data to long format
    df = stack(df, [:re75, :re78])
    df.year = ifelse.(df.variable.=="re75", 1975, 1978)
    select!(df, Not(:variable))
    rename!(df, :value=>:re)
    sort!(df, :id)
    open(GzipCompressorStream, "data/nsw.csv.gz", "w") do stream
        CSV.write(stream, df)
    end
end

# Convert mpdta from the did R package to csv format
function mpdta()
    df = load("data/mpdta.rda")["mpdta"]
    df.first_treat = convert(Vector{Int}, df.first_treat)
    select!(df, Not(:treat))
    open(GzipCompressorStream, "data/mpdta.csv.gz", "w") do stream
        CSV.write(stream, df)
    end
end

function make()
    hrs()
    nsw()
    mpdta()
end
