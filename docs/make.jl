using WeakKeyIdDicts
using Documenter

makedocs(; modules=[WeakKeyIdDicts],
         sitename="WeakKeyIdDicts.jl",
         authors="Beacon Biosignals")

deploydocs(; repo="github.com/beacon-biosignals/WeakKeyIdDicts.jl.git",
           push_preview=true,
           devbranch="main")
