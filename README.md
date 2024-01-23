# Optimization / inference of interacting particle dynamics 

Interacting particles simulator implementing parallel computing with optimization and inference frameworks for their dynamics. The Active Brownian Particles (ABP) model is used and different parameters such as particle radius or velocity can be set. The project builds on a first version of the simulator that can be found at https://github.com/microrobotlab/active-brownian-particles.


## How to use the simulator

The core code for the simulator is located in *src* folder (out of *optimization* and *inference* subfolders). It can be run in two different ways:

 1. Setting the parameters manually and calling it from *scripts/run_params.jl*.
 2. Using a CSV file that contains parameters to be tested (one line per set of parameters) and calling it from *scripts/run_file.jl*. Only some of them can be set this way and the file must be put in *data/parameters* folder where an example is shown.

The code provides a description of all adjustable parameters.


## Optimization 

As mentioned, the project features a preliminary version of an optimization framework for particle dynamics. In the current version, the goal is to apply optimization methods to the simulator to find physical parameters maximizing the *"order"* in particles behavior.

The framework can be used through the *optimizer.jl* file located in the *src/optimization* folder.


## Inference

Another part of the project is dedicated to the application of automatic inference methods for particle dynamics. From data on particle positions and orientations over time, we want to determine the dynamics that govern them.

The main code for this part can be found in the *src/inference* folder. Inference is done on data coming from the simulator itself in which particle dynamics can be changed.  A more detailed description is provided in the *python_sindy.jl* file from which the inference process can be launched (only very simple dynamics were tested for now).


## Performance test 

As mentioned, this project is based on a previous version of the simulator and, in particular, a work has been carried out to improve its performances using parallel computing. For performance-related study, the *src/test* folder includes :

 - A *profiling* subfolder in which the *profiling.jl* file can be used to generate a *Flame Graph* corresponding to a simulator run. It allows for visualizing execution time repartition.
 - A *performance* folder containing code to run, store and plot statistics on simulation times for multiple runs and parameters. A performance comparison can in particular be established with the original (saved in *ABP original_main.jl* file) and parallel versions of the simulator, varying parallelization parameters. 


## Other

The *_research/scripts* folder contains secondary codes, earlier versions and tests. 

 - The optimization folder contains in particular some methods for sampling and visualizing the objective function used in the optimization process as an "order" metric (see *first_study_expectation.jl*, *first_study_pf.jl*, *landscape_plot.jl*, *landscape_study.jl* and *number_of_samples.jl*).

