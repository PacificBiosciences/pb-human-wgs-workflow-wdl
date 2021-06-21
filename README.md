# pbRUGD-workflow

## Workflow for the comprehensive detection and prioritization of variants in human genomes with PacBio HiFi reads

_Note_: Workflow is committed.  Web app code to come.

## Authors

- William Rowell ([@williamrowell](https://github.com/williamrowell))
- Aaron Wenger ([@amwenger](https://github.com/amwenger))

## Description

This repo consists of three [Snakemake](https://snakemake.readthedocs.io/en/stable/) workflows:

1. [process_smrtcells](#process_smrtcells)
2. [process_samples](#process_samples)
3. [process_cohorts](#process_cohorts)

### `process_smrtcells`

- find new HiFi BAMs or FASTQs under `smrtcells/ready/*/`
- align HiFi reads to reference (GRCh38 by default) with [pbmm2](https://github.com/PacificBiosciences/pbmm2)
- calculate aligned coverage depth with [mosdepth](https://github.com/brentp/mosdepth)
- calculate depth ratios (chrX:chrY, chrX:chr2) from mosdepth summary to check for sample swaps
- calculate depth ratio (chrM:chr2) from mosdepth summary to check for consistency between runs
- count kmers in HiFi reads using [jellyfish](https://github.com/gmarcais/Jellyfish), dump and export modimers

### `process_sample`

- launch once sample has been sequenced to sufficient depth
- discover and call structural variants with [pbsv](https://github.com/PacificBiosciences/pbsv)
- call small variants with [DeepVariant](https://github.com/google/deepvariant)
- phase small variants with [WhatsHap](https://github.com/whatshap/whatshap/)
- merge per SMRT Cell BAMs and tag merged bam with haplotype based on WhatsHap phased DeepVariant variant calls
- merge jellyfish kmer counts
- assemble reads with [hifiasm](https://github.com/chhylp123/hifiasm) and calculate stats with [calN50.js](https://github.com/lh3/calN50)
- align assembly to reference with [minimap2](https://github.com/lh3/minimap2)
- check for sample swaps by calculate consistency of kmers between sequencing runs

### `process_cohort`

- launched once all samples in cohort have been processed
- if multi-sample cohort
  - jointly call structural variants with pbsv
  - jointly call small variants with [GLnexus](https://github.com/dnanexus-rnd/GLnexus)
- using [slivar](https://github.com/brentp/slivar)
  - annotate variant calls with population frequency from [gnomAD](https://gnomad.broadinstitute.org) and [HPRC](https://humanpangenome.org) variant databases
  - filter variant calls according to population frequency and inheritance patterns
  - detect possible compound heterozygotes, and filter to remove cis-combinations
  - assign a phenotype rank (Phrank) score, based on [Jagadeesh KA, *et al.* 2019. *Genet Med*.](https://doi.org/10.1038/s41436-018-0072-y)

## Dependencies

- some tools (e.g. pbsv) require linux
- conda
- singularity >= 3.5.3 installed by root
- `environment.yaml`

## Configuration

- `config.yaml` contains file paths and version numbers for docker images
- `reference.yaml` contains file paths and names related to reference
- `*.cluster.yaml` contains example cluster configuration for a slurm cluster with a `compute` queue for general compute and a `ml` queue for GPU.
