# Example Data

A collection of data files are provided here for the ease of testing and illustrations.
The included data are modified from the original sources
and stored in `.csv` files.
See [`make.py`](src/make.py) for the source code
that generates these files from the original data.

[DiffinDiffsBase.jl](https://github.com/JuliaDiffinDiffs/DiffinDiffsBase.jl)
provides methods for looking up and loading these example data.
Call `exampledata()` for a name list of the available datasets.
To load one of them into a `DataFrame`, use the method `exampledata(name)`.

## Sources and Licenses

| Name | Source | File Link | License | Note |
| :--- | :----: | :-------: | :-----: | :--- |
| hrs | [Dobkin et al. (2018)](#DobkinFK18E) | [HRS_long.dta](https://doi.org/10.3886/E116186V1-73160) | [CC BY 4.0](https://doi.org/10.3886/E116186V1-73120) | Data are processed as in [Sun and Abraham (2020)](#SunA20) |

## References

<a name="DobkinFK18E">**Dobkin, Carlos, Finkelstein, Amy, Kluender, Raymond, and Notowidigdo, Matthew J.** 2018. "Replication data for: The Economic Consequences of Hospital Admissions." *American Economic Association* [publisher], Inter-university Consortium for Political and Social Research [distributor]. https://doi.org/10.3886/E116186V1.</a>

<a name="SunA20">**Sun, Liyang, and Sarah Abraham.** 2020. "Estimating Dynamic Treatment Effects in Event Studies with Heterogeneous Treatment Effects." *Journal of Econometrics*, forthcoming.</a>
