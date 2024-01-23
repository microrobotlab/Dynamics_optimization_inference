using DrWatson
using CSV, DataFrames
using Plots


# For different values of simulator parameters [HERE PARTICLE RADIUS R AND SPEED v BUT COULD BE OTHERS, see 
# src/ABP main_parallel.jl for more details], we compute polarization factor averaged over time and over multiple 
# runs (multiple runs for a fixed set of parameters, only initial particle positions vary) and saved it in 
# data/processed/saved_valuations.csv. The data was generated by landscape_study.jl. In the following, we 
# plot the result as a visualization of the landscape of the objective function since averaged polarization 
# factor is used as the objective function for simulator optimization 
# (see src/optimization and _research/scripts/optimization).

# Extract data as a dataframe
# `datadir` from DrWatson provides path to data directory to which we can add "processed/" and "saved_valuations.csv"
# (see https://juliadynamics.github.io/DrWatson.jl/dev/project/#Navigating-a-Project-1)
df = CSV.read(datadir("processed", "saved_valuations.csv"), DataFrame)

plot()
# Group values by radius R
for df_Ri in groupby(df, :R)
    # plot mean polarization factor with respect to particle velocity v on 
    # different curves corresponding to different values of particle radii R
    # Sort with respect to v
    order = sortperm(df_Ri[!, :v])
    plot!(df_Ri[!, :v][order], df_Ri[!, :mean_polarization_factor][order], label="R=$(df_Ri[1, :R])")
end

ylims!(0, 1.0) # polarization factor ∈ [0,1] so plot with this range to stay objective

# Here we know it was averaged over 200 runs but if we want cleaner code 
# we should make the value data-dependent in title
NB_RUNS = 200
title!("Polarization factor averaged over time and $NB_RUNS runs w.r.t. velocity (for different radii)", titlefontsize=8)
xlabel!("velocity")
ylabel!("mean polarization factor")