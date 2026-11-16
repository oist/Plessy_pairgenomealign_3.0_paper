Summary of the answers
======================

Answers collected on 9 and 12 November 2026 (`runs.tsv`), scored against the
checklist of `README.md`.  Summarised in the Methods of the article, section "Use
of artificial intelligence".

Prompt B
--------

✓ proposed, ~ partly, – absent.

| Checklist item | Seqera AI | Sakana (Namazu) | duck.ai (GPT-6) | Google | duck.ai (Gemma 4) | M365 Copilot (GPT-5) | Claude (Opus 5.5) |
|---|---|---|---|---|---|---|---|
| Main aligner | LAST | LASTZ, chain/net | minimap2, Cactus | minimap2, Cactus, chain/net | minimap2 | minimap2 | LAST |
| 1. One-to-one or net | ✓ | ✓ | ~ | ✓ | – | ~ | ✓ |
| 2. Per-pair score training | ✓ | – | – | – | – | – | ✓ |
| 3. Tandem-repeat masking | ✓ | – | – | ~ | – | – | ✓ |
| 4. Combined indexed file for browsers | ~ | – | – | ~ | ~ | – | ~ |
| 5. CIGAR length limit | – | – | – | – | – | – | – |
| 6. Contig boundaries on dot plots | – | – | – | – | – | – | – |
| 7. Report on all pairs | ✓ | ✓ | ✓ | ✓ | ✓ | ~ | ✓ |
| 8. Substitution statistics per pair | ✓ | ~ | ~ | ~ | ~ | ~ | ✓ |
| 9. Full-size tests | ✓ | – | ~ | ✓ | – | ~ | ✓ |
| 10. Millions of scaffolds | ✓ | ✓ | ✓ | ✓ | ~ | ✓ | ✓ |

Notes:
- Seqera AI named nf-core/pairgenomealign in its answer to prompt A, and its answer
  to prompt B describes the design of the pipeline (LAST, per-pair training,
  `last-split` to many-to-one then one-to-one, tantan, NEAR/RY/MAM seeds, MultiQC),
  although it states that it designed from first principles.
- Item 4: Gemma proposes indexed BAM files per query, from which `samtools`
  extracts a region across all queries; Google proposes HAL; Seqera proposes
  indexed one-to-one MAF files per query, joined by region; Claude proposes
  indexed one-to-one MAF files per pair, stacked into a target-anchored MAF for
  selected regions.
- Item 5: Claude names 32-bit coordinate limits (PSL, chain, BAI), not the
  CIGAR length limit.
- Item 10: Google, Sakana and Gemma would discard scaffolds shorter than 0.5–1 kb
  by default.

Prompt A
--------

Seqera AI recommends nf-core/pairgenomealign.  Claude proposes LAST without naming
a pipeline.  The other answers propose minimap2 and PAF, with SyRI, QUAST or UCSC
chain/net.

Origin of the Claude answers
----------------------------

Terms of the two Claude answers were searched in the documentation of LAST 1542
(Debian package `last-align` 1542-1, including `last-cookbook.rst`), in the notes
of Martin Frith on genome alignment (github.com/mcfrith/last-genome-alignments,
commit f967a6a, 2023-06-02) and in the documentation and configuration of
nf-core/pairgenomealign 3.0.4 (README, `docs/`, `nextflow_schema.json`,
`conf/modules.config`).

- Answer to prompt A.  Its LAST commands follow the LAST documentation and
  Frith's notes (`last-train --revsym -C2`, `lastal -C2 -D1e9`, `last-split
  -m1e-5`, `last-postmask`; `maf-swap`, which only Frith's notes use, as LAST 1542
  uses `last-split -r` instead).  Its interface matches the pipeline: parameters
  `--target`, `--input` (samplesheet of `id,fasta`), `--seed` and `--lastal_args`
  with the pipeline's default `-C2 -D1e9`; masking options `-R11 -c` or `-R01 -c`,
  the switch of the pipeline's `--softmask` parameter; file suffixes `.m2o` and
  `.o2o`.  Among these sources, only the pipeline uses `-R11` and the `m2o` and
  `o2o` abbreviations.  The answer also names the GenomicBreaks R package of the
  authors' laboratory for downstream analysis.
- Answer to prompt B, which asks not to reuse an existing pipeline.  It contains
  none of these pipeline-specific terms.  Its LAST usage (per-pair `last-train
  --revsym`, one-to-one by `maf-swap` and `last-split`, tantan, MAM4/MAM8/RY/NEAR
  seeds, `lastdb5`) is described in the LAST documentation and Frith's notes.

These comparisons show which public texts the answers resemble, not what the
model was trained on.

Ideas not in nf-core/pairgenomealign
------------------------------------

- Choice of seed from a sketch distance such as Mash (six answers).
- Target index split into volumes and query chunking for very large genomes.
- `last-postmask`.
- A guard against genomes that are entirely lowercase.
- Synteny-block and breakpoint tables flagging junctions at scaffold ends.
- Flags for organelle sequences and circular genomes.
- Synthetic test genomes with known rearrangements, used as truth.
- A pilot run that extrapolates the CPU time and stops above a cap (Claude).

Limits
------

- One run per prompt and agent.
- Web search status not recorded.
- Scored by Claude (Anthropic), which knew the design of the pipeline: not blind.
  The Claude answers were therefore scored by the system that wrote them, in
  another account.
