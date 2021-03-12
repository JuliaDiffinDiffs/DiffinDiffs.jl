# Example Data

A collection of data files are provided here for the ease of testing and illustrations.
The included data are modified from the original sources
and stored in compressed CSV (`.csv.gz`) files.
See [`data/src/make.jl`](src/make.jl) for the source code
that generates these files from original data.

[DiffinDiffsBase.jl](https://github.com/JuliaDiffinDiffs/DiffinDiffsBase.jl)
provides methods for looking up and loading these example data.
Call `exampledata()` for a name list of the available datasets.
To load one of them, call `exampledata(name)`
where `name` is the `Symbol` of filename without extension (e.g., `:hrs`).

## Sources and Licenses

| Name | Source | File Link | License | Note |
| :--- | :----: | :-------: | :-----: | :--- |
| hrs | [Dobkin et al. (2018)](https://doi.org/10.1257/aer.20161038) | [HRS_long.dta](https://doi.org/10.3886/E116186V1-73160) | [CC BY 4.0](https://doi.org/10.3886/E116186V1-73120) | Data are processed as in [Sun and Abraham (2020)](https://doi.org/10.1016/j.jeconom.2020.09.006) |
| nsw | [Diamond and Sekhon (2013)](https://doi.org/10.1162/REST_a_00318) | [ec675_nsw.tab](https://doi.org/10.7910/DVN/23407/DYEWLO) | [CC0 1.0](https://dataverse.org/best-practices/harvard-dataverse-general-terms-use) | Data are rearranged in a long format as in the R package [DRDID](https://github.com/pedrohcgs/DRDID/blob/master/data-raw/nsw.R) |
| mpdta | [Callaway and Sant'Anna (2020)](https://doi.org/10.1016/j.jeconom.2020.12.001) | [mpdta.rda](https://github.com/bcallaway11/did/blob/master/data/mpdta.rda) | [GPL-2](https://cran.r-project.org/web/licenses/GPL-2) | |

## References

<a name="CallawayS20">**Callaway, Brantly, and Pedro H. C. Sant'Anna.** 2020. "Difference-in-Differences with Multiple Time Periods." *Journal of Econometrics*, forthcoming.</a>

<a name="DiamondS13G">**Diamond, Alexis and Jasjeet S. Sekhon.** 2013. "Replication data for: Genetic Matching for Estimating Causal Effects: A General Multivariate Matching Method for Achieving Balance in Observational Studies." *MIT Press* [publisher], Harvard Dataverse [distributor]. https://doi.org/10.7910/DVN/23407/DYEWLO.</a>

<a name="DobkinFK18E">**Dobkin, Carlos, Amy Finkelstein, Raymond Kluender, and Matthew J. Notowidigdo.** 2018. "Replication data for: The Economic Consequences of Hospital Admissions." *American Economic Association* [publisher], Inter-university Consortium for Political and Social Research [distributor]. https://doi.org/10.3886/E116186V1.</a>

<a name="SunA20">**Sun, Liyang, and Sarah Abraham.** 2020. "Estimating Dynamic Treatment Effects in Event Studies with Heterogeneous Treatment Effects." *Journal of Econometrics*, forthcoming.</a>
