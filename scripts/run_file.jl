# To call run function (see ABP output) with parameters from file

using DrWatson
@quickactivate "active-brownian-particles"
println("Currently in $(projectdir()) environment !")

include(srcdir("ABP output.jl"))


#---------------------------------------------------------------------------------------------------------------------
# CALL RUNNER WITH ARGUMENTS FROM FILE

# THE FILE MUST BE IN data/parameters 
param_file_name = "instance1.csv"

# macro-parameters
wall_condition = "periodic"; nb_runs = 2

# CSV export parameters: `save_stride` is the stride for timesteps while saving simulator output
save_stride = 10 

# animation parameters: `animation_stride` stride for the animation
animate = true; animation_filename = nothing; animation_stride = 10

# parallelization parameters: (N, M) number of cells (rows, columns)
N = 16; M = 16;

# simulation progress bar display
verbose = false


run_from_file(param_file_name; wall_condition=wall_condition, 
    nb_runs=nb_runs, 
    save_stride=save_stride,
    animate=animate, animation_stride=animation_stride,
    N=N, M=M,
    verbose=verbose);
