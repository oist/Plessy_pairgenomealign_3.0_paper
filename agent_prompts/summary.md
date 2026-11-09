Summary of the answers
======================

Answers collected on 9 November 2026 (`runs.tsv`), scored against the checklist of
`README.md`.  Summarised in the Methods of the article, section "Use of artificial
intelligence".

Prompt B
--------

✓ proposed, ~ partly, – absent.

| Checklist item | Seqera AI | Sakana (Namazu) | duck.ai (GPT-6) | Google | duck.ai (Gemma 4) | M365 Copilot (GPT-5) |
|---|---|---|---|---|---|---|
| Main aligner | LAST | LASTZ, chain/net | minimap2, Cactus | minimap2, Cactus, chain/net | minimap2 | minimap2 |
| 1. One-to-one or net | ✓ | ✓ | ~ | ✓ | – | ~ |
| 2. Per-pair score training | ✓ | – | – | – | – | – |
| 3. Tandem-repeat masking | ✓ | – | – | ~ | – | – |
| 4. Combined indexed file for browsers | ~ | – | – | ~ | ~ | – |
| 5. CIGAR length limit | – | – | – | – | – | – |
| 6. Contig boundaries on dot plots | – | – | – | – | – | – |
| 7. Report on all pairs | ✓ | ✓ | ✓ | ✓ | ✓ | ~ |
| 8. Substitution statistics per pair | ✓ | ~ | ~ | ~ | ~ | ~ |
| 9. Full-size tests | ✓ | – | ~ | ✓ | – | ~ |
| 10. Millions of scaffolds | ✓ | ✓ | ✓ | ✓ | ~ | ✓ |

Notes:
- Seqera AI named nf-core/pairgenomealign in its answer to prompt A, and its answer
  to prompt B describes the design of the pipeline (LAST, per-pair training,
  `last-split` to many-to-one then one-to-one, tantan, NEAR/RY/MAM seeds, MultiQC),
  although it states that it designed from first principles.
- Item 4: Gemma proposes indexed BAM files per query, from which `samtools`
  extracts a region across all queries; Google proposes HAL; Seqera proposes
  indexed one-to-one MAF files per query, joined by region.
- Item 10: Google, Sakana and Gemma would discard scaffolds shorter than 0.5–1 kb
  by default.

Prompt A
--------

Seqera AI recommends nf-core/pairgenomealign.  The other answers propose minimap2
and PAF, with SyRI, QUAST or UCSC chain/net.

Ideas not in nf-core/pairgenomealign
------------------------------------

- Choice of seed from a sketch distance such as Mash (five answers).
- Target index split into volumes and query chunking for very large genomes.
- `last-postmask`.
- A guard against genomes that are entirely lowercase.
- Synteny-block and breakpoint tables flagging junctions at scaffold ends.
- Flags for organelle sequences and circular genomes.
- Synthetic test genomes with known rearrangements, used as truth.

Limits
------

- One run per prompt and agent.
- Web search status not recorded.
- Scored by Claude (Anthropic), which knew the design of the pipeline: not blind.
