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
