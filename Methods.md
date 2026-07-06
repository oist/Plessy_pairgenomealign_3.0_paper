Methods
=======

Software deployment and versions
--------------------------------

The nf-core modules used in this pipeline run Free Software packaged by the
Bioconda (BibTeX Gruening_2018,) project, installed by Nextflow on the users
system directly in conda environments, or by downloading containers.  The two
main software sources are BioContainers (BibTeX Leprevost_2017; Bai_2021),
built in one-to-one correspondence with Bioconda packages, or Wave containers
(BibTeX seqera_wave), which allow to combine Bioconda and conda-forge (BibTeX
conda_forge_zenodo) packages in a single image.  The containers are built in
Docker/Podman format (BibTeX DiTommaso_2015), and also available for
Singularity/Apptainer (BibTex Kurtzer_2017) via the Galaxy project (BibTex
Afgan_2016,) for the Biocondainers or Sequera for Wave containers. The
containers can be cached and shared between users.  The nf-core modules for
LAST use minimal containers that have various and overlapping contents, and  to
avoid the downloading of multiple redundant containers the pairgenome pipeline
overrides them to use a single container providing LAST version 1651, samtools,
htslib and bcftools version 1.23.1, conda-forge open-fonts version 0.7.0 (for
plotting sequence names in dotplots), gzip version 1.14, bgzip version 1.0.8
and xz version 5.8.3.


Orchestration, slurm, local, AWS (test\_full), institutional profiles.

Software configuration
----------------------

Modularised software are modularised via a script template containing
parametrable and hardcoded arguments at the discretion of the module maitainer.
The parametrble argsumenbts are either tied to the pipeline's command-line
options, or passed through standard variables allowing the users to add or
override arguments via the use of nextflow configuration files.  In addition,
parameters relevant to all modules such as CPU threads are accessed through
their own flags.  Finally, the maximum amount of time and memory allocated to
the containers are preset for broad classes (list single, light, medium,
heavy), and can also be overriden.

Copilot, please standardise arguments, options, parameters in a readable way.


Alignment parameters
-------------------

Before indexing, the lowercase soft masks of the target genome are erased and
replaced by a simple tandem repeat masking using an internal implementation of
tantan (BibTex Frith_2010b) in LAST (lastdb's option -R01).  This can be
overriden with the piepeline option `--softmask original`.  Both strands of the
target are indexed (lastdb's option -S2).  This speeds the aligment of the
query at the expense of memory usage.  Also, this can cause the output to
feature aligments where the minus strand of the target is aligned to the plus
strand of the query, which is not well handled by some downstream tools.  For
these reasons it can be reverted with the pipeline option `--strand both`).
The standard seed is `RY4` and can be changed with the `--seed` option.

Parameter training is constrained to return symmetric scores and gap penalties
with last-train's `-revsym --gapsym --matsym` options.  The user can revert it
by setting `ext.args` to a different value for the `ALIGNMENT_TRAIN` process in
a nextflow configuration file when the it is known that the symmetry is broken,
for instance in mitochondrial genomes that have heavy and light strands.  In
addition, the user can also provide a parameter file through the
`--lastal_params` that will be applied identically to all query genomes.  This
parameter file can either be generated from a previous run or be a standard
LAST scoring matrix.

The multi-threaded LAST commands are given at most 12 CPU cores, capped by the
maxima defined for the orchestrator by the user or the institutional profile.
The result alignment is not expected to change, but the output order may so,
thus the pipeline results are only guaranteed to be bit-identical when the same
number of CPU cores are given.  This is verifiable by runnign the pipeline
regresion tests, which comprise reference checksums of the most important
output files.

Copilot, the text is heavy because it has to be clear about what is a software
argument and what is a pipeline parameter.  Please feel free to reword.

AI version
----------

The nf-core modules used in this pipeline rely on Free Software distributed through
Bioconda (\cite{Gruening_2018}). Depending on the execution environment, these
packages are installed automatically by Nextflow in isolated conda environments or
provided through software containers. The default container sources are
BioContainers (\cite{Leprevost_2017}; \cite{Bai_2021}), which maintain a one-to-one
correspondence with Bioconda packages, and Wave containers
(\cite{seqera_wave}), which can combine packages from both Bioconda and
conda-forge (\cite{conda_forge_zenodo}) within a single image. Containers are
distributed in Docker-compatible formats (\cite{DiTommaso_2015}) and can also be
used through Singularity/Apptainer (\cite{Kurtzer_2017}), with BioContainers
images converted and distributed by the Galaxy project (\cite{Afgan_2016}) and
Wave images provided through Seqera. Container images may be cached locally and
shared between users, reducing software installation overhead and improving
reproducibility.

The nf-core modules implementing the LAST alignment workflow use several minimal
containers with partially overlapping software dependencies. To avoid repeated
downloads of redundant images, the pairgenome pipeline overrides the default
module configuration and provides a single shared container containing LAST
v1651, samtools, htslib, and bcftools v1.23.1, open-fonts v0.7.0 from
conda-forge (required for rendering sequence names in dotplots), gzip v1.14,
bgzip v1.0.8, and xz v5.8.3.

Software components are modularised through script templates that combine
hard-coded tool arguments with configurable process parameters defined by the
module maintainer. Configurable parameters are either linked directly to
pipeline command-line options or passed through standard nf-core module
variables, allowing users to modify or extend the resulting tool arguments via
Nextflow configuration files. Resource settings that apply across modules,
such as the number of CPU threads, are controlled through dedicated
parameters.

Maximum execution times and memory allocations are assigned according to broad
resource classes, ranging from lightweight to computationally intensive
processes. These default settings can be overridden through standard Nextflow
configuration mechanisms to match the requirements of specific computing
environments.


