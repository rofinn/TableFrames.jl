#######################################
# Show code from DataFrames.jl :(
#######################################
#' @exported
#' @description
#'
#' Returns a string summary of an DataFrame in a standardized
#' form. For example, a standard DataFrame with 10 rows and 5 columns
#' will be summarized as "10×5 DataFrame".
#'
#' @param df::DataFrame The DataFrame to be summarized.
#'
#' @returns res::String The summary of `df`.
#'
#' @examples
#'
#' summary(DataFrame(A = 1:10))
function Base.summary(df::DataFrame) # -> String
    nrows, ncols = size(df)
    return @sprintf("%d×%d %s", nrows, ncols, typeof(df))
end

#' @description
#'
#' Determine the number of characters that would be used to print a value.
#'
#' @param x::Any A value whose string width will be computed.
#'
#' @returns w::Int The width of the string.
#'
#' @examples
#'
#' ourstrwidth("abc")
#' ourstrwidth(10000)
let
    local io = IOBuffer(Vector{UInt8}(80), true, true)
    global ourstrwidth
    function ourstrwidth(x::Any) # -> Int
        truncate(io, 0)
        ourshowcompact(io, x)
        return position(io)
    end
    ourstrwidth(x::AbstractString) = strwidth(x) + 2 # -> Int
    ourstrwidth(s::Symbol) = Int(ccall(
        :u8_strwidth,
        Csize_t,
        (Ptr{UInt8}, ),
        Base.unsafe_convert(Ptr{UInt8}, s)
    ))
end

#' @exported
#' @description
#'
#' Render an DataFrame to an IO system. The specific visual
#' representation chosen depends on the width of the REPL window
#' from which the call to `show` derives. If the DataFrame could not
#' be rendered without splitting the output into chunks, a summary of the
#' columns is rendered instead of rendering the raw data. This dynamic
#' response to screen width can be configured using the argument
#' `splitchunks`.
#'
#' @param io::IO The IO system to which `df` will be printed.
#' @param df::DataFrame An DataFrame.
#' @param splitchunks::Bool Should the printing of the DataFrame
#'        be done in chunks? Defaults to `false`.
#' @param rowlabel::Symbol What label should be printed when rendering the
#'        numeric ID's of each row? Defaults to `"Row"`.
#' @param displaysummary::Bool Should a brief string summary of the
#'        DataFrame be rendered to the IO system before printing the
#'        contents of the renderable rows? Defaults to `true`.
#'
#' @returns o::Void A `nothing` value.
#'
#' @examples
#'
#' df = DataFrame(A = 1:3, B = ["x", "y", "z"])
#' show(STDOUT, df, false, :Row, true)
function Base.show(
    io::IO,
    df::DataFrame,
    splitchunks::Bool=true,
    rowlabel::Symbol = Symbol("Row"),
    displaysummary::Bool = true
)
    nrows = size(df, 2)
    dsize = displaysize(io)
    availableheight = dsize[1] - 5
    nrowssubset = fld(availableheight, 2)
    bound = min(nrowssubset - 1, nrows)
    if nrows <= availableheight
        rowindices1 = 1:nrows
        rowindices2 = 1:0
    else
        rowindices1 = 1:bound
        rowindices2 = max(bound + 1, nrows - nrowssubset + 1):nrows
    end
    maxwidths = getmaxwidths(df, rowindices1, rowindices2, rowlabel)
    width = getprintedwidth(maxwidths)
    showrows(
        io,
        df,
        rowindices1,
        rowindices2,
        maxwidths,
        splitchunks,
        rowlabel,
        displaysummary
    )
end

#' @description
#'
#' Render a subset of rows (possibly in chunks) of an DataFrame to an
#' IO system. Users can control
#'
#' NOTE: The value of `maxwidths[end]` must be the string width of
#' `rowlabel`.
#'
#' @param io::IO The IO system to which `df` will be printed.
#' @param df::DataFrame An DataFrame.
#' @param rowindices1::AbstractVector{Int} The indices of the first subset
#'        of rows to be rendered.
#' @param rowindices2::AbstractVector{Int} The indices of the second subset
#'        of rows to be rendered. An ellipsis will be printed before
#'        rendering this second subset of rows.
#' @param maxwidths::Vector{Int} The pre-computed maximum string width
#'        required to render each column.
#' @param splitchunks::Bool Should the printing of the DataFrame
#'        be done in chunks? Defaults to `false`.
#' @param rowlabel::Symbol What label should be printed when rendering the
#'        numeric ID's of each row? Defaults to `"Row"`.
#' @param displaysummary::Bool Should a brief string summary of the
#'        DataFrame be rendered to the IO system before printing the
#'        contents of the renderable rows? Defaults to `true`.
#'
#' @returns o::Void A `nothing` value.
#'
#' @examples
#'
#' df = DataFrame(A = 1:3, B = ["x", "y", "z"])
#' showrows(STDOUT, df, 1:2, 3:3, [1, 1, 5], false, :Row, true)
function showrows(
    io::IO,
    df::DataFrame,
    rowindices1::AbstractVector{Int},
    rowindices2::AbstractVector{Int},
    maxwidths::Vector{Int},
    splitchunks::Bool = false,
    rowlabel::Symbol = Symbol("Row"),
    displaysummary::Bool = true
)
    ncols = size(df, 1)

    if displaysummary
        println(io, summary(df))
    end

    if isempty(rowindices1)
        return
    end

    rowmaxwidth = maxwidths[ncols + 1]
    chunkbounds = getchunkbounds(maxwidths, splitchunks, displaysize(io)[2])
    nchunks = length(chunkbounds) - 1
    _names = collect(names(df))

    for chunkindex in 1:nchunks
        leftcol = chunkbounds[chunkindex] + 1
        rightcol = chunkbounds[chunkindex + 1]

        # Print column names
        @printf io "│ %s" rowlabel
        padding = rowmaxwidth - ourstrwidth(rowlabel)
        for itr in 1:padding
            write(io, ' ')
        end
        @printf io " │ "
        for j in leftcol:rightcol
            s = _names[j]
            ourshowcompact(io, s)
            padding = maxwidths[j] - ourstrwidth(s)
            for itr in 1:padding
                write(io, ' ')
            end
            if j == rightcol
                print(io, " │\n")
            else
                print(io, " │ ")
            end
        end

        # Print table bounding line
        write(io, '├')
        for itr in 1:(rowmaxwidth + 2)
            write(io, '─')
        end
        write(io, '┼')
        for j in leftcol:rightcol
            for itr in 1:(maxwidths[j] + 2)
                write(io, '─')
            end
            if j < rightcol
                write(io, '┼')
            else
                write(io, '┤')
            end
        end
        write(io, '\n')

        # Print main table body, potentially in two abbreviated sections
        showrowindices(
            io,
            df,
            rowindices1,
            maxwidths,
            leftcol,
            rightcol
        )

        if !isempty(rowindices2)
            print(io, "\n⋮\n")
            showrowindices(
                io,
                df,
                rowindices2,
                maxwidths,
                leftcol,
                rightcol
            )
        end

        # Print newlines to separate chunks
        if chunkindex < nchunks
            print(io, "\n\n")
        end
    end

    return
end

#' @description
#'
#' Calculates, for each column of an DataFrame, the maximum
#' string width used to render either the name of that column or the
#' longest entry in that column -- among the rows of the DataFrame
#' will be rendered to IO. The widths for all columns are returned as a
#' vector.
#'
#' NOTE: The last entry of the result vector is the string width of the
#'       implicit row ID column contained in every DataFrame.
#'
#' @param df::DataFrame The DataFrame whose columns will be
#'        printed.
#' @param rowindices1::AbstractVector{Int} A set of indices of the first
#'        chunk of the DataFrame that would be rendered to IO.
#' @param rowindices2::AbstractVector{Int} A set of indices of the second
#'        chunk of the DataFrame that would be rendered to IO. Can
#'        be empty if the DataFrame would be printed without any
#'        ellipses.
#' @param rowlabel::AbstractString The label that will be used when rendered the
#'        numeric ID's of each row. Typically, this will be set to "Row".
#'
#' @returns widths::Vector{Int} The maximum string widths required to render
#'          each column, including that column's name.
#'
#' @examples
#'
#' df = DataFrame(A = 1:3, B = ["x", "yy", "z"])
#' maxwidths = getmaxwidths(df, 1:1, 3:3, :Row)
function getmaxwidths(
    df::DataFrame,
    rowindices1::AbstractVector{Int},
    rowindices2::AbstractVector{Int},
    rowlabel::Symbol
)
    maxwidths = Vector{Int}(size(df, 1) + 1)
    undefstrwidth = ourstrwidth(Base.undef_ref_str)

    j = 1
    for (name, col) in zip(names(df), columns(df))
        # (1) Consider length of column name
        maxwidth = ourstrwidth(name)

        # (2) Consider length of longest entry in that column
        for indices in (rowindices1, rowindices2)
            for i in indices
                try
                    maxwidth = max(maxwidth, ourstrwidth(col[i]))
                catch
                    maxwidth = max(maxwidth, undefstrwidth)
                end
            end
        end
        maxwidths[j] = maxwidth
        j += 1
    end

    rowmaxwidth1 = isempty(rowindices1) ? 0 : ndigits(maximum(rowindices1))
    rowmaxwidth2 = isempty(rowindices2) ? 0 : ndigits(maximum(rowindices2))

    maxwidths[j] = max(max(rowmaxwidth1, rowmaxwidth2), ourstrwidth(rowlabel))

    return maxwidths
end

#' @description
#'
#' Given the maximum widths required to render each column of an
#' DataFrame, this returns the total number of characters
#' that would be required to render an entire row to an IO system.
#'
#' NOTE: This width includes the whitespace and special characters used to
#'       pretty print the DataFrame.
#'
#' @param maxwidths::Vector{Int} The maximum width needed to render each
#'        column of an DataFrame.
#'
#' @returns totalwidth::Int The total width required to render a complete row
#'          of the DataFrame for which `maxwidths` was computed.
#'
#' @examples
#'
#' df = DataFrame(A = 1:3, B = ["x", "yy", "z"])
#' maxwidths = getmaxwidths(df, 1:1, 3:3, "Row")
#' totalwidth = getprintedwidth(maxwidths))
function getprintedwidth(maxwidths::Vector{Int}) # -> Int
    # Include length of line-initial |
    totalwidth = 1
    for i in 1:length(maxwidths)
        # Include length of field + 2 spaces + trailing |
        totalwidth += maxwidths[i] + 3
    end
    return totalwidth
end

#' @description
#'
#' When rendering an DataFrame to a REPL window in chunks, each of
#' which will fit within the width of the REPL window, this function will
#' return the indices of the columns that should be included in each chunk.
#'
#' NOTE: The resulting bounds should be interpreted as follows: the
#'       i-th chunk bound is the index MINUS 1 of the first column in the
#'       i-th chunk. The (i + 1)-th chunk bound is the EXACT index of the
#'       last column in the i-th chunk. For example, the bounds [0, 3, 5]
#'       imply that the first chunk contains columns 1-3 and the second chunk
#'       contains columns 4-5.
#'
#' @param maxwidths::Vector{Int} The maximum width needed to render each
#'        column of an DataFrame.
#' @param splitchunks::Bool Should the output be split into chunks at all or
#'        should only one chunk be constructed for the entire
#'        DataFrame?
#' @param availablewidth::Int The available width in the REPL.
#'
#' @returns chunkbounds::Vector{Int} The bounds of each chunk of columns.
#'
#' @examples
#'
#' df = DataFrame(A = 1:3, B = ["x", "yy", "z"])
#' maxwidths = getmaxwidths(df, 1:1, 3:3, "Row")
#' chunkbounds = getchunkbounds(maxwidths, true)
function getchunkbounds(maxwidths::Vector{Int},
                        splitchunks::Bool,
                        availablewidth::Int=displaysize()[2]) # -> Vector{Int}
    ncols = length(maxwidths) - 1
    rowmaxwidth = maxwidths[ncols + 1]
    if splitchunks
        chunkbounds = [0]
        # Include 2 spaces + 2 | characters for row/col label
        totalwidth = rowmaxwidth + 4
        for j in 1:ncols
            # Include 2 spaces + | character in per-column character count
            totalwidth += maxwidths[j] + 3
            if totalwidth > availablewidth
                push!(chunkbounds, j - 1)
                totalwidth = rowmaxwidth + 4 + maxwidths[j] + 3
            end
        end
        push!(chunkbounds, ncols)
    else
        chunkbounds = [0, ncols]
    end
    return chunkbounds
end

#' @description
#'
#' Render a subset of rows and columns of an DataFrame to an
#' IO system. For chunked printing, this function is used to print a
#' single chunk, starting from the first indicated column and ending with
#' the last indicated column. Assumes that the maximum string widths
#' required for printing have been precomputed.
#'
#' @param io::IO The IO system to which `df` will be printed.
#' @param df::DataFrame An DataFrame.
#' @param rowindices::AbstractVector{Int} The indices of the subset of rows
#'        that will be rendered to `io`.
#' @param maxwidths::Vector{Int} The pre-computed maximum string width
#'        required to render each column.
#' @param leftcol::Int The index of the first column in a chunk to be
#'        rendered.
#' @param rightcol::Int The index of the last column in a chunk to be
#'        rendered.
#'
#' @returns o::Void A `nothing` value.
#'
#' @examples
#'
#' df = DataFrame(A = 1:3, B = ["x", "y", "z"])
#' showrowindices(STDOUT, df, 1:2, [1, 1, 5], 1, 2)
function showrowindices(
    io::IO,
    df::DataFrame,
    rowindices::AbstractVector{Int},
    maxwidths::Vector{Int},
    leftcol::Int,
    rightcol::Int
)
    rowmaxwidth = maxwidths[end]

    for i in rowindices
        # Print row ID
        @printf io "│ %d" i
        padding = rowmaxwidth - ndigits(i)
        for _ in 1:padding
            write(io, ' ')
        end
        print(io, " │ ")
        # Print DataFrame entry
        _names = collect(names(df))
        for j in leftcol:rightcol
            strlen = 0
            try
                strlen = ourstrwidth(df[_names[j], i])
                ourshowcompact(io, df[_names[j], i])
            catch
                strlen = ourstrwidth(Base.undef_ref_str)
                ourshowcompact(io, Base.undef_ref_str)
            end
            padding = maxwidths[j] - strlen
            for _ in 1:padding
                write(io, ' ')
            end
            if j == rightcol
                if i == rowindices[end]
                    print(io, " │")
                else
                    print(io, " │\n")
                end
            else
                print(io, " │ ")
            end
        end
    end
    return
end

#' @description
#'
#' Render a value to an IO object in a compact format. Unlike
#' Base.showcompact, we render strings without surrounding quote
#' marks.
#'
#' @param io::IO An IO object to be printed to.
#' @param x::Any A value to be printed.
#'
#' @returns x::Void A `nothing` value.
#'
#' @examples
#'
#' ourshowcompact(STDOUT, "abc")
#' ourshowcompact(STDOUT, 10000)
ourshowcompact(io::IO, x::Any) = showcompact(io, x) # -> Void
ourshowcompact(io::IO, x::AbstractString) = showcompact(io, x) # -> Void
ourshowcompact(io::IO, x::Symbol) = print(io, x) # -> Void