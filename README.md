# TableFrames

[![stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://rofinn.github.io/TableFrames.jl/stable)
[![latest](https://img.shields.io/badge/docs-latest-blue.svg)](https://rofinn.github.io/TableFrames.jl/latest)
[![Build Status](https://travis-ci.org/rofinn/TableFrames.jl.svg?branch=master)](https://travis-ci.org/rofinn/TableFrames.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/github/rofinn/TableFrames.jl?svg=true)](https://ci.appveyor.com/project/rofinn/TableFrames-jl)
[![codecov](https://codecov.io/gh/rofinn/TableFrames.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/rofinn/TableFrames.jl)

Both [DataFrames](https://github.com/JuliaStats/DataFrames.jl) and [DataTables](https://github.com/JuliaData/DataTables.jl) are
coupled to the underlying array structures [DataArrays](https://github.com/JuliaStats/DataArrays.jl) and
[NullableArrays](https://github.com/JuliaStats/NullableArrays.jl) respectively.
TableFrames.jl provides a minimal interface for storing and manipulating tabular data agnostic to the storage method.
Given the current collection of existing packages for representing tabular data the name "TableFrames" is not intended to be taken seriously and
this package will never be registered. **This is only a prototype!***

## Proposal

`DataFrame`s simply specify a set of restrictions and operations around an `Associative{Symbol, <:AbstractVector}` (e.g., `Store{<:AbstractVector}`).

### Restrictions

- All columns (value vectors) must be the same length.
- All column names are `Symbol`s
- All column data must of type `AbstractVector`

### Operations

#### Indexing

- Indexing by a single column name returns the `AbstractVector` for that column.
- Indexing by row number returns the `NamedTuple` for that row.
- Indexing by a column and multiple rows returns a `view` of the `AbstractVector` for that column
- Indexing by multiple columns (and multiple rows) will return an new `DataFrame` with the specified columns and references to the original data.

#### Iteration

- Iterating over `keys` and `values` to maintain an associative-like interface.
- Iterating over `names` should return the `Symbol` names for each column.
- Iterating over `columns` should return the vectors for each column.
- Iterating over `rows` should return `NamedTuple`s for each row.

#### Mutation

- Set columns, rows and elements
- `insert!` a new row into the table.
- `append!` rows from one `DataFrame` into another.
- `add` a column to a table (this will create a new table as it changes the parameterization of the columns)
- `merge!` columns from one `DataFrame` into another.

### Avoided Operations

- Handling missing data (e.g., `dropna`)
- Providing more complex methods (e.g., `join`, `sort`, `by`, `aggregate`).
- Conversion to other formats (table types or arrays).
- Exporting to different file formats.
- Table indexing (e.g., arbitrary row indexing and querying), although we might want to provide some API for extending.
- Statistical Modeling