version 1.0

# A simplified data structure, Array[SampleInfo], is used here, and unffacted/affected lines are all removed by Charlie Bi
# Whenever affected/unaffected appears, it is removed and rewritten with one line of new code
#
# fasta_conversion's ourtput is returned here

import "fasta_smrtcells.wdl"
import "../common/structs.wdl"

workflow fasta_person {
  input {
    SampleInfo sample
    String pb_conda_image
  }

  scatter(smrtcell_info in sample.smrtcells) {
    call fasta_smrtcells.fasta_smrtcells as smrtcells {
      input :
        smrtcell_info = smrtcell_info,
        pb_conda_image = pb_conda_image
    }
  }

  output {
    Array[String] parents_names = sample.parents
    String sample_names  = sample.name
    Pair[String, Array[File]] sample_fasta = (sample.name, smrtcells.movie_fasta)
  }
}

