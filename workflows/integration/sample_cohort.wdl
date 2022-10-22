version 1.0

#import "../sample/sample.wdl"
#import "../cohort/cohort.wdl"
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/sample.trial.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/cohort/cohort.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

workflow sample_cohort {
  input {
    Array[String]             affected_person_sample_names
    Array[Array[IndexedData]] affected_person_sample
    Array[Array[File]]        affected_person_jellyfish_input
    Array[String]             unaffected_person_sample_names
    Array[Array[IndexedData]] unaffected_person_sample
    Array[Array[File]]        unaffected_person_jellyfish_input

    String cohort_name
    File regions_file
    IndexedData reference

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
    String glnexus_image
  }

  call sample.trial.sample_trial {
    input:
      affected_person_sample_names = affected_person_sample_names,
      affected_person_sample = affected_person_sample,
      affected_person_jellyfish_input = affected_person_jellyfish_input,
      unaffected_person_sample_names = unaffected_person_sample_names,
      unaffected_person_sample = unaffected_person_sample,
      unaffected_person_jellyfish_input = unaffected_person_jellyfish_input,

      regions_file = regions_file,
      reference = reference,

      tr_bed = tr_bed,
      chr_lengths = chr_lengths,

      pb_conda_image = pb_conda_image,
      deepvariant_image = deepvariant_image,
  }

  call cohort.cohort {
    input:
      cohort_name = cohort_name,
      regions_file = regions_file,
      reference = reference,
      chr_lengths = chr_lengths, 

      affected_person_deepvariant_phased_vcf_gz = sample_trial.affected_person_deepvariant_phased_vcf_gz,
      unaffected_person_deepvariant_phased_vcf_gz = sample_trial.unaffected_person_deepvariant_phased_vcf_gz,
      
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

      affected_person_bams = affected_person_sample,
      unaffected_person_bams = unaffected_person_sample,
      affected_person_gvcfs = sample_trial.affected_person_gvcf,
      unaffected_person_gvcfs = sample_trial.unaffected_person_gvcf,

      pb_conda_image = pb_conda_image,
      glnexus_image = glnexus_image
  }

  output {
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
