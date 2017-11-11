module TableFrames

export DataFrame, record, columns, rows

using NamedTuples
using DataStructures
using DataStreams

const Store{T<:AbstractVector} = Associative{Symbol, T}

struct DataFrame{S<:Store{<:AbstractVector}, cols}
    data::S
end

function DataFrame(data::Store{<:AbstractVector})
    samelen(values(data)) || throw(ArgumentError("All columns of the DataFrame must be of the same length"))
    DataFrame{typeof(data), tuple(keys(data)...)}(data)
end

function DataFrame(data::Pair{Symbol, <:AbstractVector}...)
    T = typejoin((typeof(d.second) for d in data)...)
    return DataFrame(OrderedDict{Symbol, T}(data...))
end

Base.eltype(df::DataFrame) = eltype(df.data)
Base.isempty(df::DataFrame) = isempty(df.data)
Base.size(df::DataFrame) = isempty(df) ? (0, 0) : (length(df.data), length(first(values(df.data))))
Base.size(df::DataFrame, dim::Int) = size(df)[dim]

#####################
# Indexing Protocol
#####################
# Single-column based indexing
Base.getindex(df::DataFrame, col::Symbol) = df.data[col]
Base.getindex(df::DataFrame, col::Symbol, row::Int) = df.data[col][row]
Base.getindex(df::DataFrame, col::Symbol, rows::AbstractVector{Int}) = view(df.data[col], rows)

# Multi-column based indexing
function Base.getindex(df::DataFrame, cols::Vector{Symbol})
    selected = map(cols) do col
        col => df.data[col]
    end |> typeof(df.data)

    return DataFrame(selected)
end

function Base.getindex(df::DataFrame, cols::Vector{Symbol}, row::Int)
    return map(cols) do col
        col => df.data[col][row]
    end |> record
end

function Base.getindex(df::DataFrame, cols::Vector{Symbol}, rows::AbstractVector{Int})
    selected = map(cols) do col
        col => view(df.data[col], rows)
    end |> typeof(df.data)

    return DataFrame(selected)
end

# Row-only based indexing
Base.getindex(df::DataFrame, row::Int) = getindex(df, collect(keys(df.data)), row)
Base.getindex(df::DataFrame, rows::AbstractVector{Int}) = getindex(df, collect(keys(df.data)), rows)

# Set single value
Base.setindex!(df::DataFrame, val::Any, col::Symbol, row::Int)= df[col][row] = val

# Set entire column
function Base.setindex!(df::DataFrame, val::AbstractVector, col::Symbol)
    samelen(values(df), length(val)) || throw(ArgumentError("All columns of the DataFrame must be of the same length"))
    df[col] = val
end

# Set a row
function Base.setindex!(df::DataFrame, val::Union{NamedTuple, Associative}, row::Int)
    for col in keys(val)
        df[col, row] = val[col]
    end
end

#######################################
# Iteration Protocols
#######################################
Base.keys(df::DataFrame) = keys(df.data)
Base.values(df::DataFrame) = values(df.data)
names(df::DataFrame) = keys(df)
columns(df::DataFrame) = values(df)

struct RowIterator
    df::DataFrame
end

rows(df::DataFrame) = RowIterator(df)
Base.start(itr::RowIterator) = 1
Base.done(itr::RowIterator, i::Int) = i > size(itr.df, 2)
Base.next(itr::RowIterator, i::Int) = (itr.df[i], i + 1)
Base.length(itr::RowIterator) = size(itr.df, 2)
Base.eltype(itr::RowIterator) = NamedTuple

################################################
# Methods for creating NamedTuple row records.
###############################################
record(fields::Pair...) = record([fields...])

function record(fields::Vector{<:Pair})
    unzipped = collect(zip(fields...))
    return record([unzipped[1]...], [unzipped[2]...])
end

function record(names::Vector{<:Symbol}, vals::Vector)
    nt = NamedTuples.create_namedtuple_type(names)
    return nt(vals...)
end

#=
Simply checks that all columns are the same length
or that all columns match the default value.
=#
function samelen(cols, default=-1)
    result = true
    len = default

    for col in cols
        if len < 0
            len = length(col)
        elseif length(col) != len
            result = false
            break
        end
    end

    return result
end

include("show.jl")
include("io.jl")

end  # module
