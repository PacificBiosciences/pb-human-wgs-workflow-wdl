version 1.0

import "./smrtcells.person.wdl" as smrtcells_person

workflow smrtcells_family {
  input {
    String md5sum_name

    IndexedData reference
    String reference_name
    CohortInfo cohort
    Int kmer_length

    String pb_conda_image
  }

  scatter (sample in cohort.affected_patients) {
    call smrtcells_person.smrtcells_person as smrtcells_affected_patient {
      input:
        md5sum_name = md5sum_name,

        reference = reference,
        reference_name = reference_name,
        sample = sample,
        kmer_length = kmer_length,

        pb_conda_image = pb_conda_image
    }
  }

  scatter (sample in cohort.unaffected_patients) {
    call smrtcells_person.smrtcells_person as smrtcells_unaffected_patient {
      input:
        md5sum_name = md5sum_name,

        reference = reference,
        reference_name = reference_name,
        sample = sample,
        kmer_length = kmer_length,

        pb_conda_image = pb_conda_image
    }
  }

  output {
    Array[Array[IndexedData]] affected_patient_bam_pairs = smrtcells_affected_patient.bam_pairs
    Array[Array[File]] affected_patient_jellyfish_count = smrtcells_affected_patient.jellyfish_count

    Array[Array[IndexedData]] unaffected_patient_bam_pairs = smrtcells_unaffected_patient.bam_pairs
    Array[Array[File]] unaffected_patient_jellyfish_count = smrtcells_unaffected_patient.jellyfish_count
  }
}
