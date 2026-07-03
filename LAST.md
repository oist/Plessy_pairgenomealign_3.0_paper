AI prompt
=========

These are bibliographic notes used to write about the use of LAST in this
manuscript.

The notes are intentionally verbose and may contain details not relevant to the
manuscript.  This is because it is easier to remove details than to add some.

Bibliographic references are given through BibTeX IDs linking to
`Template_for_both_PCI_and_PCJ/PCJ-sample.bib`.  It is essential to not change
them.

The format of this file is Markdown.

You are assisting me in writing the introduction of a scientific article.

Please read the Template_for_both_PCI_and_PCJ/PCJ-sample.bib file, the
bibliographic notes and the introduction paragraph below, and propose me a
brushed up paragraph that is terse but acessible to non-specialist, precise and
complete.  Please format it in BibTeX format.

Bibliographic notes
-------------------

The primary paper for LAST is Frith, Hamada and Horton, 2010 (BibTeX
Frith_2010).  LAST “find initial matches, extend them using a gapless X-drop
algorithm, and finally extend them using a gapped X-drop algorithm”.  It
reports that “masking tandem repeats is sufficient”.  “we empirically assess
many parameter choices on whole genome alignments of several organisms. We were
able to perform many thousands of genome alignments only by using our new
alignment software, LAST.”

LAST lets the user select or design alignment seeds (Frith and Noé 2014, BibTeX
Frith_2014), using a scheme that allows for spaced seeds (containing
mismatches), transition-constrained seeds (tolerating transitions but not
transversions), adaptative seeds (lenght is not fixed) and sparse seeds
(restricting the search space).

Recent versions of LAST offer a set of “inexact seeds” (spaced and subset
seeds, BibTeX Frith_2020) made of non-overlapping words using the two-letter
alphabet R (A or G) and Y (C or T) and reduce the seed space from 1/4th (RY4)
to 1/128th (RY128) of the genome. Frith, Shaw and Spouge, 2023 (BibTeX
Frith_2023).

The `last-split` program (Frith and Kawaguchi, 2015, BibTeX Frith_2015) is
crucial to this pipeline as it transforms the many-to-many target-to-query
alignment into a many-to-one and then a one-to-one relationship, thus resolving
multimapping regions. “Optimal set of local alignments. Striking example of
intra-chromosomal loss of synteny between D. melanogaster and D. pseudoobscura.
Heuristic approach inspired by the “repeated matches algorithm” of Durbin and
coll., 1998.”

The `last-train` software (Hamada ane coll., 2017, BibTeX Hamada_2017) allows
to infer the alignment parameters using an iterative approach algning a sample
of the query sequence to the indexed target sequence.  It allows us to align a
list of queries to a single target without worring about the differences of
evolutionary distances from the target to each query.


Introduction about LAST
-----------------------

We chose the LAST software (BibTeX Frith_2010) to align pairs of genomes
because of its ability to handle a broad variety of sequence lengths,
divergences and biases, and because of its ability to reduce a many-to-many
aligment result in to an optimal set of one-to-one aligments (BibTeX
Frith_2015), which is simpler than post hoc chaining and netting
(BibTeX Kent_2003) to resolve competing mappings.  LAST lets the user chose an
alignment seed to decide the tradeoff between sensitivity and specificity
(BibTeX Frith_2020, BibTeX Frith_2023) and is able to discover the optimal
aligment parameters (scoring matrix and gap creation/extension) by iself
(BibTeX Hamada_2017).

Other software are available but did not offer all the features of LAST.  In
particular, LASTZ (BibTeX Harris_2007) and MUMmer (Marcais_2018) are slower,
Minimap2 (BibTeX Li_2018) is not designed to align distantly and FASTGA
(Myers_2025) was not available at the time the core of this pipeline was
developped.

Once computed, whole-genome alignments can be stored in formats that may
discard part of the information.  The MAF format was originally used by
alignemnt tools related to the UCSC genome browser (Kent_2002a), such as MULTIZ
(Blanchette_2004) and is the primary output of LAST, which not only uses it to
report the alignment but also the per-base quality value of the aligment.  In
this text-based format, the self-aligment of a genome takes as much space as
twice the genome itself, which is not convenient for applications that do not
need the exact aligment.  The tabular output of LAST and the PSL format of BLAT
(Kent_2002b) discard the alignment but report statisics such as the number of
mismatches and the position of gaps.  This information is not compressed
efficiently, and formats like the tabular output of BLAST (Altschul_1990)
discards it.  Finally, pairs of aligment coordinates in each genome can be
stored in GFF and BED formats without further information than the alignment
score, reaching close to maximal lossy compaction in text format.  In addition,
the MAF-formatted alignments can also be converted almost losslessly to the
SAM/BAM format (Li_2009) and benefit from reference-based compression in CRAM
format (Bonfield_2022).  The LAST suite is able to either output or to export
to each of these format.


Copilot version:
----------------

We used the LAST software (Frith_2010) for pairwise genome alignment because it
accommodates a wide range of sequence lengths, divergences and compositional
biases, while implementing an efficient seed-and-extend strategy with
successive gapless and gapped X-drop extensions. A key advantage of LAST is its
flexible seeding framework, which allows users to tune sensitivity and
specificity through the design of exact or inexact seeds, including spaced,
transition-constrained, and sparsely sampled seeds (Frith_2014, Frith_2020,
Frith_2023). In addition, the last-train procedure automatically infers
substitution scores and gap penalties from the data, enabling robust alignment
across queries with heterogeneous evolutionary distances (Hamada_2017). The
resulting local alignments are then processed by last-split, which selects an
optimal set of non-overlapping alignments to produce a consistent one-to-one
mapping between genomes, thereby resolving multi-mapping regions in a
principled manner (Frith_2015). This integrated approach avoids the need for
post hoc chaining and netting strategies (Kent_2003) while maintaining high
sensitivity and specificity.

Several alternative pairwise alignment tools were considered, including LASTZ,
MUMmer4, Minimap2, and, more recently, FastGA (Harris_2007; Marcais_2018;
Li_2018; Myers_2025). LASTZ and MUMmer4 are widely used for whole-genome
comparison, but neither combines the flexible seeding strategies, adaptive
parameter training, and probabilistic split-alignment framework provided by
LAST in a single integrated workflow. Minimap2 achieves excellent performance
for read mapping and alignment of closely related long sequences but was not
primarily designed for sensitive alignment of more diverged genomes. FastGA
offers substantially improved speed for genome alignment; however, it became
available after the core design and implementation of the present pipeline. We
therefore selected LAST because it uniquely combined broad applicability across
evolutionary distances with configurable sensitivity, data-driven parameter
training, and principled resolution of ambiguous alignments.

Whole-genome alignments can be stored in formats that differ substantially in
information content and storage efficiency. The Multiple Alignment Format
(MAF), introduced for the UCSC Genome Browser and related tools such as MULTIZ
(\cite{Kent_2002a}; \cite{Blanchette_2004}), is the primary output format of
LAST. In addition to alignment coordinates, MAF stores the aligned sequences
and, in LAST, per-base alignment confidence values. This richness comes at a
cost: a self-alignment occupies roughly twice the space of the underlying
genome sequence, making MAF unnecessarily large for applications that do not
require base-level alignment information. More compact formats trade
information for storage efficiency. The tabular output of LAST and the PSL
format used by BLAT (\cite{Kent_2002b}) omit the alignment strings while
retaining summary statistics such as mismatch counts and gap sizes. BLAST
tabular output (\cite{Altschul_1990}) is more compact still, discarding the gap
structure itself. At the most compact end of the spectrum, alignments can be
represented simply as paired genomic intervals in GFF or BED format with only
an alignment score, providing near-maximal lossy compression in a text
representation. Conversely, MAF alignments can be converted with minimal
information loss to SAM/BAM (\cite{Li_2009}) and subsequently compressed in
CRAM format (\cite{Bonfield_2022}), benefiting from reference-based
compression. The LAST suite can directly generate or export all of these
formats.
