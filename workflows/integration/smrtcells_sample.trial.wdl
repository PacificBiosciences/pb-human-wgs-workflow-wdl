version 1.0

#import "../smrtcells/smrtcells.trial.wdl"
#import "../sample/sample.trial.wdl"
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/bemosk/pb-human-wgs-workflow-wdl/bemosk-integration/workflows/smrtcells/smrtcells.trial.wdl"
import "https://raw.githubusercontent.com/bemosk/pb-human-wgs-workflow-wdl/bemosk-integration/workflows/sample/sample.trial.wdl"
import "https://raw.githubusercontent.com/bemosk/pb-human-wgs-workflow-wdl/bemosk-integration/workflows/common/structs.wdl"

workflow smrtcells_sample_trial {
  input {
    IndexedData reference
    File regions_file
    CohortInfo cohort_info
    Int kmer_length

    File tr_bed
    File chr_lengths

    String pb_conda_image
    String deepvariant_image
    String picard_image
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
  }
}
