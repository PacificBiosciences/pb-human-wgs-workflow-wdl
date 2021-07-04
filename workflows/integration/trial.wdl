version 1.0

#import "../integration/smrtcells_sample.trial.wdl"
#import "../cohort/cohort.wdl"
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/bemosk/pb-human-wgs-workflow-wdl/bemosk-integration/workflows/integration/smrtcells_sample.trial.wdl"
import "https://raw.githubusercontent.com/bemosk/pb-human-wgs-workflow-wdl/bemosk-integration/workflows/cohort/cohort.wdl"
import "https://raw.githubusercontent.com/bemosk/pb-human-wgs-workflow-wdl/bemosk-integration/workflows/common/structs.wdl"

workflow trial {
  input {
    String cohort_name
    IndexedData reference
    Array[String] regions
    CohortInfo cohort
    Int kmer_length

    File tr_bed
    File chr_lengths

    String pb_conda_image
    String deepvariant_image
    String picard_image
    String glnexus_image
  }

  call smrtcells_sample_trial.smrtcells_sample_trial {
    input:
      reference = reference,
      regions = regions,
      cohort = cohort,
      kmer_length = kmer_length,

      tr_bed = tr_bed,
      chr_lengths = chr_lengths,

      pb_conda_image = pb_conda_image,
      deepvariant_image = deepvariant_image,
      picard_image = picard_image
  }

  call cohort.cohort {
    cohort_name = cohort_name,
    regions = regions,
    reference = reference,

    affected_person_deepvariant_phased_vcf_gz     = smrtcells_sample_trial.affected_person_deepvariant_phased_vcf_gz,
    unaffected_person_deepvariant_phased_vcf_gz = = smrtcells_sample_trial.unaffected_person_deepvariant_phased_vcf_gz,

    pb_conda_image = pb_conda_image,
    glnexus_image = glnexus_image
  }

  output {
    Array[String] affected_person_sample_names                     = smrtcells_sample_trial.affected_person_sample_names
    Array[Array[IndexedData]] affected_person_bams                 = smrtcells_sample_trial.affected_person_bams
    Array[Array[File]] affected_person_jellyfish_count             = smrtcells_sample_trial.affected_person_jellyfish_count

    Array[String] unaffected_person_sample_names                   = smrtcells_sample_trial.unaffected_person_sample_names
    Array[Array[IndexedData]] unaffected_person_bams               = smrtcells_sample_trial.unaffected_person_bams
    Array[Array[File]] unaffected_person_jellyfish_count           = smrtcells_sample_trial.unaffected_person_jellyfish_count

    Array[IndexedData] affected_person_gvcf                        = smrtcells_sample_trial.affected_person_gvcf
    Array[Array[Array[File]]] affected_person_svsig_gv             = smrtcells_sample_trial.affected_person_svsig_gv
    Array[IndexedData] affected_person_deepvariant_phased_vcf_gz   = smrtcells_sample_trial.affected_person_deepvariant_phased_vcf_gz

    Array[IndexedData] unaffected_person_gvcf                      = smrtcells_sample_trial.unaffected_person_gvcf
    Array[Array[Array[File]]] unaffected_person_svsig_gv           = smrtcells_sample_trial.unaffected_person_svsig_gv
    Array[IndexedData] unaffected_person_deepvariant_phased_vcf_gz = smrtcells_sample_trial.unaffected_person_deepvariant_phased_vcf_gz

    IndexedData pbsv_vcf    = cohort.pbsv_vcf
    IndexedData filt_vcf    = cohort.filt_vcf
    IndexedData comphet_vcf = cohort.filt_vcf
    File filt_tsv           = cohort.filt_tsv
    File comphet_tsv        = cohort.comphet_tsv
}
