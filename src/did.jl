"""
    RegressionBasedDID <: DiffinDiffsEstimator

Estimation procedure for regression-based difference-in-differences.
"""
const RegressionBasedDID = DiffinDiffsEstimator{:RegressionBasedDID,
    Tuple{CheckData, CheckVcov, CheckVars, MakeWeights, CheckFEs, MakeFESolver,
    MakeYXCols, MakeTreatCols}}

const Reg = RegressionBasedDID

