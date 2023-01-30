version 1.0

# A simplified data structure, Array[SampleInfo], is used here, and unffacted/affected lines are all removed by Charlie Bi
# Whenever affected/unaffected appears, it is removed and rewritten with one line of new code

import "fasta_person.wdl"
import "../common/structs.wdl"


workflow fasta_cohort {
  input {
    Array[SampleInfo] cohort_info
    String pb_conda_image
  }

  scatter (sample in cohort_info) {
    call fasta_person.fasta_person as fasta_person {
      input:
        sample = sample,
        pb_conda_image = pb_conda_image
    }
  }

  output {
    Array[Pair[String, Array[File]]] fasta_info = fasta_person.sample_fasta
    Array[String] person_sample_names = if defined(fasta_person.sample_names)     then fasta_person.sample_names      else []
    Array[Array[String]] person_parents_names = if defined(fasta_person.parents_names)     then fasta_person.parents_names      else []
  }
}
