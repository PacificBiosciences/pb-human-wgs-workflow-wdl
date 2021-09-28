# pbRUGD-workflow

## Workflow for the comprehensive detection and prioritization of variants in human genomes with PacBio HiFi reads

_Note_: Workflow is committed.  Web app code to come.

## Authors

- William Rowell ([@williamrowell](https://github.com/williamrowell))
- Aaron Wenger ([@amwenger](https://github.com/amwenger))

## Contributors

- Roberto Lleras ([@ducatiMonster916](https://github.com/ducatimonster916))
- Matt McLoughlin ([@MattMcL4475](https://github.com/MattMcL4475))
- Ben Moskowitz ([@bemosk](https://github.com/bemosk))

## Description

This repo consists of three [Cromwell](https://cromwell.readthedocs.io/en/stable/) workflows:

1. [smrtcells.wdl](#smrtcells.wdl)
2. [samples.wdl](#sample.wdl)
3. [cohort.wdl](#cohort.wdl)

### `smrtcells.wdl`

- Input is either new HiFi BAMs or FASTQs in a container of your choosing. Refer to the [**Getting Started**][] document for information about setting up your run.
- Align HiFi reads to reference (GRCh38 by default) with [pbmm2](https://github.com/PacificBiosciences/pbmm2)
- Calculate aligned coverage depth with [mosdepth](https://github.com/brentp/mosdepth)
- Calculate depth ratios (chrX:chrY, chrX:chr2) from mosdepth summary to check for sample swaps
- Calculate depth ratio (chrM:chr2) from mosdepth summary to check for consistency between runs
- Count kmers in HiFi reads using [jellyfish](https://github.com/gmarcais/Jellyfish), dump and export modimers

### `sample.wdl`

- Run this workflow once a sample has been sequenced to sufficient depth. Refer to the [**Getting Started**][] document for information about setting up your run.
- Discover and call structural variants with [pbsv](https://github.com/PacificBiosciences/pbsv)
- Call small variants with [DeepVariant](https://github.com/google/deepvariant)
- Phase small variants with [WhatsHap](https://github.com/whatshap/whatshap/)
- Merge per SMRT Cell BAMs and tag merged bam with haplotype based on WhatsHap phased DeepVariant variant calls
- Merge jellyfish kmer counts
- Assemble reads with [hifiasm](https://github.com/chhylp123/hifiasm) and calculate stats with [calN50.js](https://github.com/lh3/calN50)
- Align assembly to reference with [minimap2](https://github.com/lh3/minimap2)
- Check for sample swaps by calculate consistency of kmers between sequencing runs

### `Cohort.wdl`

- Run this workflow once all samples in cohort have been processed. Refer to the [**Getting Started**][] document for information about setting up your run.
- if multi-sample cohort
  - jointly call structural variants with pbsv
  - jointly call small variants with [GLnexus](https://github.com/dnanexus-rnd/GLnexus)
- using [slivar](https://github.com/brentp/slivar)
  - annotate variant calls with population frequency from [gnomAD](https://gnomad.broadinstitute.org) and [HPRC](https://humanpangenome.org) variant databases
  - filter variant calls according to population frequency and inheritance patterns
  - detect possible compound heterozygotes, and filter to remove cis-combinations
  - assign a phenotype rank (Phrank) score, based on [Jagadeesh KA, *et al.* 2019. *Genet Med*.](https://doi.org/10.1038/s41436-018-0072-y)

## Dependencies

- These workflows are designed to run in a deployed instance of [Cromwell on Azure][https://github.com/microsoft/CromwellOnAzure].
- All tools have been containerized with [Docker][https://www.docker.com/] for reproducability & portability between environments.

## Configuration
# Most settings for workflows are configurable at the input file level for convenience. Most users will leave the settings in Reference and Docker inputs to defaults.
- `defaultsettings.*runtype*.inputs.json` contains connmonly configurable paths and settings to specify per run.
- `reference.*runtype*.inputs.json` contains file paths and names related to reference datasets
- `docker.*runtype*.inputs.json` contains the version numbers for deployed containers leveraged by various tasks in the workflows.
