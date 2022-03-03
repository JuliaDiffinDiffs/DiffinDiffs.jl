# Results

```@autodocs
Modules = [DiffinDiffsBase, InteractionWeightedDIDs]
Pages = ["src/did.jl"]
Filter = t -> !(typeof(t) === DataType && t <: DiffinDiffsEstimator)
```
