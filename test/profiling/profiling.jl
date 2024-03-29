# THIS CODE GENERATES FLAMEGRAPHS FOR THE SIMULATOR
# (see https://github.com/timholy/ProfileView.jl)

using DrWatson
using ProfileView, BenchmarkTools

# `srcdir` from DrWatson provides path to src/. We add to the string folder/file names provided in arguments.
include(srcdir("ABP output.jl"))
# Same for `projectdir` which provides path to current project 
include(projectdir("test", "ABP main_original.jl"))


#---------------------------------------------------------------------------------------------------------------------
# SIMULATOR PARAMETERS FOR PROFILING 

# simulation parameters
Nt = 10000; Np = 20; L = 100.; R = 1.5; v = 10.

# macro-parameters
wall_condition = "periodic"; collision_correction = false; nb_runs = 1

# CSV export parameters: `save_stride` is the stride for timesteps while saving simulator output
save = false; save_stride = 10 

# animation parameters: `animation_filename` must end with ".gif" if provided, `animation_stride` stride for the animation
animate = false; animation_filename = nothing; animation_stride = 10

# parallization parameters: (N, M) number of cells (rows, columns), (x_min, x_max, y_min, y_max) considered region for the cell division
ϵ = 0.1 # little margin for the region
N = 16; M = 16; x_min = -L/2 - ϵ; x_max = L/2 + ϵ; y_min = -L/2 - ϵ; y_max = L/2 + ϵ


# ----- FLAMGRAPH GENERATION
# For parallel version of the simulator
# ProfileView.@profview run((Nt=Nt,Np=Np,L=L,R=R,v=v); wall_condition=wall_condition, collision_correction=collision_correction, animate=animate, animation_stride=animation_stride, N=N, M=M);

# For original version of the simulator
# /!\ BEWARE OF NAME CONFLICTS, `multiparticleE_wall` IS USED IN PARALLEL AND NON-PARALLEL VERSIONS OF THE SIMULATOR 
ProfileView.@profview multiparticleE_wall(Np, L, R, v, Nt);
