version 1.0

#import "./smrtcells.person.wdl" as smrtcells_person
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/bemosk/pb-human-wgs-workflow-wdl/bemosk-integration/workflows/smrtcells/smrtcells.person.wdl" as smrtcells_person
import "https://raw.githubusercontent.com/bemosk/pb-human-wgs-workflow-wdl/bemosk-integration/workflows/common/structs.wdl"

workflow smrtcells_trial {
  input {
    IndexedData reference
    CohortInfo cohort
    Int kmer_length

    String pb_conda_image
  }

  scatter (sample in cohort.affected_persons) {
    call smrtcells_person.smrtcells_person as smrtcells_affected_person {
      input:
        reference = reference,
        sample = sample,
        kmer_length = kmer_length,

        pb_conda_image = pb_conda_image
    }
  }

  scatter (sample in cohort.unaffected_persons) {
    call smrtcells_person.smrtcells_person as smrtcells_unaffected_person {
      input:
        reference = reference,
        sample = sample,
        kmer_length = kmer_length,

        pb_conda_image = pb_conda_image
    }
  }

  output {
    Array[String] affected_person_sample_names            = if defined(smrtcells_affected_person.sample_name)       then smrtcells_affected_person.sample_name       else []
    Array[Array[IndexedData]] affected_person_bams        = if defined(smrtcells_affected_person.bams)              then smrtcells_affected_person.bams              else []
    Array[Array[File]] affected_person_jellyfish_count    = if defined(smrtcells_affected_person.jellyfish_count)   then smrtcells_affected_person.jellyfish_count   else []

    Array[String] unaffected_person_sample_names          = if defined(smrtcells_unaffected_person.sample_name)     then smrtcells_unaffected_person.sample_name     else []
    Array[Array[IndexedData]] unaffected_person_bams      = if defined(smrtcells_unaffected_person.bams)            then smrtcells_unaffected_person.bams            else []
    Array[Array[File]] unaffected_person_jellyfish_count  = if defined(smrtcells_unaffected_person.jellyfish_count) then smrtcells_unaffected_person.jellyfish_count else []
  }
}
