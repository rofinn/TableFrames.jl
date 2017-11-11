struct DataFrameStream{S<:Store{<:AbstractVector}}
    data::S
end

DataFrameStream(df::DataFrame) = DataFrameStream(df.data)

# DataFrame Data.Source implementation
function Data.schema(df::DataFrame)
    return Data.Schema(
        Type[eltype(c) for c in columns(df)],
        string.(names(df)),
        size(df, 1) == 0 ? 0 : length(first(columns(df)))
    )
end

Data.isdone(source::DataFrame, row, col, rows, cols) = row > rows || col > cols
function Data.isdone(source::DataFrame, row, col)
    cols = size(source, 1)
    return Data.isdone(
        source,
        row,
        col,
        cols == 0 ? 0 : length(first(columns(source))),
        cols
    )
end

Data.streamtype(::Type{DataFrame}, ::Type{Data.Column}) = true
Data.streamtype(::Type{DataFrame}, ::Type{Data.Field}) = true

Data.streamfrom(source::DataFrame, ::Type{Data.Column}, ::Type{T}, row, col) where {T} =
    source[col]
Data.streamfrom(source::DataFrame, ::Type{Data.Field}, ::Type{T}, row, col) where {T} =
    source[col][row]

# DataFrame Data.Sink implementation
Data.streamtypes(::Type{DataFrame}) = [Data.Column, Data.Field]
# Data.weakrefstrings(::Type{DataFrame}) = false

function DataFrame(sch::Data.Schema{R}, ::Type{S}=Data.Field, append::Bool=false, args...; reference::Vector{UInt8}=UInt8[]) where {R, S <: Data.StreamType}
    types = Data.types(sch)
    if !isempty(args) && args[1] isa DataFrame && types == Data.types(Data.schema(args[1]))
        # passing in an existing TableFrame Sink w/ same types as source
        sink = args[1]
        sinkrows = size(Data.schema(sink), 1)
        # are we appending and either column-streaming or there are an unknown # of rows
        if append && (S == Data.Column || !R)
            sch.rows = sinkrows
            # dont' need to do anything because:
              # for Data.Column, we just append columns anyway (see Data.streamto! below)
              # for Data.Field, unknown # of source rows, so we'll just push! in streamto!
        else
            # need to adjust the existing sink
            # similar to above, for Data.Column or unknown # of rows for Data.Field,
                # we'll append!/push! in streamto!, so we empty! the columns
            # if appending, we want to grow our columns to be able to include every row
                # in source (sinkrows + sch.rows)
            # if not appending, we're just "re-using" a sink, so we just resize it
                # to the # of rows in the source
            newsize = ifelse(S == Data.Column || !R, 0,
                        ifelse(append, sinkrows + sch.rows, sch.rows))
            foreach(col->resize!(col, newsize), values(sink.data))
            sch.rows = newsize
        end
        # take care of a possible reference from source by addint to WeakRefStringArrays
        if !isempty(reference)
            foreach(col-> col isa WeakRefStringArray && push!(col.data, reference),
                sink.columns)
        end
        sink = DataFrameStream(sink)
    else
        # allocating a fresh DataFrame Sink; append is irrelevant
        # for Data.Column or unknown # of rows in Data.Field, we only ever append!,
            # so just allocate empty columns
        rows = ifelse(S == Data.Column, 0, ifelse(!R, 0, sch.rows))
        names = Data.header(sch)
        sink = DataFrameStream(
                Tuple(allocate(types[i], rows, reference) for i = 1:length(types)), names)
        sch.rows = rows
    end
    return sink
end

DataFrame(sink, sch::Data.Schema, ::Type{S}, append::Bool;
          reference::Vector{UInt8}=UInt8[]) where {S} =
    DataFrame(sch, S, append, sink; reference=reference)