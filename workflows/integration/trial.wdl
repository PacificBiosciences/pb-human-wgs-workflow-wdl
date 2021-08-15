version 1.0

#import "../smrtcells/smrtcells.trial.wdl"
#import "../sample/sample.trial.wdl"
#import "../cohort/cohort.wdl"
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/dev/workflows/smrtcells/smrtcells.trial.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/dev/workflows/sample/sample.trial.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/dev/workflows/cohort/cohort.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/dev/workflows/common/structs.wdl"

workflow trial {
  input {
    String cohort_name
    IndexedData reference
    File regions_file
    CohortInfo cohort_info
    Int kmer_length

    File tr_bed
    File chr_lengths

    File hpoannotations
    File hpoterms
    File hpodag
    File gff
    File ensembl_to_hgnc
    File js
    File lof_lookup
    File gnomad_af
    File hprc_af
    File allyaml
    File ped
    File clinvar_lookup

    String pb_conda_image
    String deepvariant_image
    String picard_image
    String glnexus_image
  }

  call smrtcells.trial.smrtcells_trial {
    input:
      reference = reference,
      cohort_info = cohort_info,
      kmer_length = kmer_length,

      pb_conda_image = pb_conda_image
  }

  call sample.trial.sample_trial {
    input:
    affected_person_sample_names      = smrtcells_trial.affected_person_sample_names,
    affected_person_sample            = smrtcells_trial.affected_person_bams,
    affected_person_jellyfish_input   = smrtcells_trial.affected_person_jellyfish_count,
    unaffected_person_sample_names    = smrtcells_trial.unaffected_person_sample_names,
    unaffected_person_sample          = smrtcells_trial.unaffected_person_bams,
    unaffected_person_jellyfish_input = smrtcells_trial.unaffected_person_jellyfish_count,

    regions_file = regions_file,
    reference = reference,

    tr_bed = tr_bed,
    chr_lengths = chr_lengths,

    pb_conda_image = pb_conda_image,
    deepvariant_image = deepvariant_image,
    picard_image = picard_image
  }

  call cohort.cohort {
    input:
      cohort_name = cohort_name,
      regions_file = regions_file,
      reference = reference,

      affected_person_deepvariant_phased_vcf_gz = sample_trial.affected_person_deepvariant_phased_vcf_gz,
      unaffected_person_deepvariant_phased_vcf_gz = sample_trial.unaffected_person_deepvariant_phased_vcf_gz,

      chr_lengths = chr_lengths, 
      
      hpoannotations = hpoannotations,
      hpoterms = hpoterms,
      hpodag = hpodag,
      gff = gff,
      ensembl_to_hgnc = ensembl_to_hgnc,
      js = js,
      lof_lookup = lof_lookup,
      clinvar_lookup = clinvar_lookup,
      gnomad_af = gnomad_af,
      hprc_af = hprc_af,
      allyaml = allyaml,
      ped = ped,

      affected_person_svsigs = sample_trial.affected_person_svsig_gv,
      unaffected_person_svsigs = sample_trial.unaffected_person_svsig_gv,

      affected_person_bams = smrtcells_trial.affected_person_bams,
      unaffected_person_bams = smrtcells_trial.unaffected_person_bams,
      affected_person_gvcfs = sample_trial.affected_person_gvcf,
      unaffected_person_gvcfs = sample_trial.unaffected_person_gvcf,

      pb_conda_image = pb_conda_image,
      glnexus_image = glnexus_image
  }

  output {
    Array[Array[IndexedData]] affected_person_bams        = smrtcells_trial.affected_person_bams
    Array[Array[File]] affected_person_jellyfish_count    = smrtcells_trial.affected_person_jellyfish_count

    Array[Array[IndexedData]] unaffected_person_bams      = smrtcells_trial.unaffected_person_bams
    Array[Array[File]] unaffected_person_jellyfish_count  = smrtcells_trial.unaffected_person_jellyfish_count

    Array[IndexedData] affected_person_gvcf                        = sample_trial.affected_person_gvcf
    Array[Array[Array[File]]] affected_person_svsig_gv             = sample_trial.affected_person_svsig_gv
    Array[IndexedData] affected_person_deepvariant_phased_vcf_gz   = sample_trial.affected_person_deepvariant_phased_vcf_gz

    Array[IndexedData] unaffected_person_gvcf                      = sample_trial.unaffected_person_gvcf
    Array[Array[Array[File]]] unaffected_person_svsig_gv           = sample_trial.unaffected_person_svsig_gv
    Array[IndexedData] unaffected_person_deepvariant_phased_vcf_gz = sample_trial.unaffected_person_deepvariant_phased_vcf_gz

    IndexedData pbsv_vcf    = cohort.pbsv_vcf
    IndexedData filt_vcf    = cohort.filt_vcf
    IndexedData comphet_vcf = cohort.comphet_vcf
    File filt_tsv           = cohort.filt_tsv
    File comphet_tsv        = cohort.comphet_tsv
  }
}
