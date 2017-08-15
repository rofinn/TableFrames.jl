using Documenter, TableFrames

makedocs(
    modules=[TableFrames],
    format=:html,
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/rofinn/TableFrames.jl/blob/{commit}{path}#L{line}",
    sitename="TableFrames.jl",
    authors="Rory Finnegan",
    assets=[],
)

deploydocs(
    repo = "github.com/rofinn/TableFrames.jl.git",
    target = "build",
    deps = nothing,
    make = nothing,
)
