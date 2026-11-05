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

Input
-----

Genomes are read in FASTA format, optionally compressed in the gzip format.
When the pipeline exports results to the BAM, BCF or CRAM formats, the genomes
are (re-)compressed with the indexable and gzip-compatible bgzip format (BibTeX
Li_2011) unless they were already bgzip-compressed.  The target genome is
passed via the `--target` command line parameter and the list of query genomes
via a text table, the "sample sheet", and the `--input` parameter.  A `--query`
command-line parameter is available for convenience when only one query genome
is given.

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

Export to SAM/BAM/BCF/CRAM formats
----------------------------------

Alignment conversion to SAM is done by the `maf-convert` tool of the LAST
package but further conversion to BAM, BCF and CRAM formats is done by shell
commands embedded in the nf-core modules that were created for this pipeline.
While these formats were initially designed for reads aligned to genomes, it is
possible to use them to reprsent multiple whole-genome alignments in a single
file.  This pipeline does so by labelling all aligments from a single query
genome as "read groups", and by representing the alignments as hard-clipped
regions in the query genome.  The longest clipped region that can be
represented in BAM and CRAM formats is 268,435,455 bases (28 bits).
Fortunately, it is possible to split longer regions as adjascent chunks.  The
CRAM format used is version 3.1 but this can be downgraded through a Nextflow
configuration file modifying `ext.args2` for`ALIGNMENT_EXP` and `ext.args` for
`ALIGNMENT_MERGE`.  Indexes are always produced for BAM, BCF and CRAM files.


Statistics and metadata collection
----------------------------------

Length and base composition statistics of query genomes are extracted with
`assemnbly-scan` version 1.0.0 (BibTex Petit_2023) unless disabled with
`--skip_assembly_qc`.  Some simple alignment statistics are collected by the
nf-core modules with shell or python scripts that are not part of the original
LAST packages, and saved in text files in the pipeline's output folder. These
statistics are alignment nucleotide identity percentages, gap insertion and
extension penalties, plus the nucleotide substitution matrix of the whole
alignment.  `seqtk cutn` version 1.5-r133 (BibTeX Li_2013) is run with `-n 10
-p 100000` to extract the coordinates of stretches of 10 `N`s or longer as they
often represent contig boundary information.  Thumbnails of the one-to-one
alignments can be geneated with `--multiqc_thumbs`.  These data are finallyr
aggregated by local subworkflows for display in a MultiQC report (BibTex
Ewels_2016).


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

Input genomes are provided in FASTA format and may optionally be compressed
with gzip. When downstream outputs are generated in BAM, BCF, or CRAM format,
the pipeline ensures that the corresponding reference genomes are available in
the block-gzip (BGZF) format by recompressing them when necessary
(\cite{Li_2011}). Existing BGZF-compressed files are reused unchanged. The use
of BGZF enables the random-access indexing required by these output formats.

The target genome is specified with the pipeline parameter
\texttt{--target}. Query genomes are specified through a sample sheet supplied
via \texttt{--input}. This table defines the collection of query genomes to be
aligned against the target. As a convenience for pairwise analyses, a single
query genome may alternatively be provided directly through the
\texttt{--query} parameter.

Prior to database construction, any existing lowercase soft masking in the
target genome is discarded and replaced with tandem-repeat masking using the
tantan implementation embedded in LAST (\cite{Frith_2011}). By default,
\texttt{lastdb} is executed with option \texttt{-R01}. This behaviour can be
disabled with the pipeline parameter \texttt{--softmask original}, which
preserves the masking present in the input assembly.

The target database is indexed on both strands using the \texttt{lastdb}
option \texttt{-S2}. This increases memory usage during indexing but accelerates
subsequent alignments. An important consequence is that some alignments may be
reported between the reverse-complement strand of the target and the forward
strand of the query, a representation that is not handled consistently by all
downstream software. Users may therefore revert to single-strand indexing with
the pipeline parameter \texttt{--strand both}. The default seed scheme is
\texttt{RY4}, although alternative seeds can be selected through the
\texttt{--seed} parameter.

Alignment parameter training is performed with symmetric substitution scores
and gap penalties by passing the \texttt{-revsym}, \texttt{--gapsym}, and
\texttt{--matsym} arguments to \texttt{last-train}. These constraints are
appropriate for most nuclear genomes but may be undesirable when evolutionary
processes differ between strands, such as in animal mitochondrial genomes. In
such cases, advanced users can override the training arguments by redefining
\texttt{ext.args} for the \texttt{ALIGNMENT\_TRAIN} process in a Nextflow
configuration file. Alternatively, a predefined LAST parameter file may be
supplied through the pipeline parameter \texttt{--lastal\_params}. The same
parameter set is then applied to all query genomes. Such files may originate
from a previous training run or correspond to a standard LAST scoring scheme.

Multi-threaded LAST processes are allocated up to 12 CPU cores, subject to any
lower limit imposed by user settings or institutional execution profiles.
Thread count is not expected to affect alignment results, but it may alter the
order in which alignments are reported. Consequently, bitwise-identical output
is guaranteed only when the same number of CPU cores is used. This behaviour is
verified by the pipeline regression tests, which compare checksums of key
output files against reference results.

Alignments are converted from MAF to SAM format using the \texttt{maf-convert}
utility distributed with LAST. Subsequent conversion to BAM, BCF, and CRAM is
performed by shell commands encapsulated in nf-core modules developed for this
pipeline. Although these formats were originally designed to store sequencing
reads aligned to a reference genome, they can also represent whole-genome
alignments. The pipeline exploits this capability by assigning a distinct read
group to each query genome and encoding genome alignments as hard-clipped
segments of the query sequence.

In BAM and CRAM files, hard-clipped regions are limited to
268,435,455~bases. Longer query sequences are therefore represented as a series
of adjacent alignment records, allowing arbitrarily long chromosomes and
scaffolds to be encoded without loss of information.

CRAM files are written in version~3.1 format by default. Advanced users may
select a different CRAM version by modifying the \texttt{ext.args2} setting of
the \texttt{ALIGNMENT\_EXP} process and the \texttt{ext.args} setting of the
\texttt{ALIGNMENT\_MERGE} process in a Nextflow configuration file. Index files
are generated automatically for all BAM, BCF, and CRAM outputs.

Assembly statistics, including sequence length and base composition, are
calculated with \texttt{assembly-scan} v1.0.0 (\cite{Petit_2023}) unless
disabled through the pipeline parameter \texttt{--skip\_assembly\_qc}. In
addition, custom nf-core modules developed for this pipeline collect summary
statistics from the alignment outputs and store them as text files within the
results directory. These statistics include alignment nucleotide identity,
gap frequencies, inferred insertion and extension penalties, and the
nucleotide substitution matrix estimated from the whole-genome alignment.

Coordinates of assembly gaps are identified with \texttt{seqtk cutN}
v1.5-r133 (\cite{Li_2013}) using the arguments \texttt{-n 10 -p 100000},
thereby reporting runs of at least ten consecutive \texttt{N} bases. Such
regions frequently correspond to contig or scaffold boundaries and provide
additional context for the interpretation of genome alignments.

Optional thumbnail representations of one-to-one alignments can be generated
with the pipeline parameter \texttt{--multiqc\_thumbs}. Assembly statistics,
alignment metrics, gap annotations, and alignment thumbnails are then
aggregated by dedicated subworkflows and presented in a consolidated MultiQC
report (\cite{Ewels_2016}).
