version 1.0

#This is a new workflow to separately run sample-level hifiasm with fasta_info, coded by Charlie Bi
#This workflow depends on the output/fasta_info from upstream running smrtcells

import "../common/structs.wdl"
import "tasks/hifiasm.wdl" as hifiasm


workflow sample_hifiasm_cohort {
  input {
    Array[Pair[String,Array[File]]] fasta_info
    String pb_conda_image
    IndexedData reference
  }

  scatter (sample in fasta_info){
    call hifiasm.hifiasm as hifiasm_sample {
      input:
        sample_name = sample.left,
        movie_fasta = sample.right,
        target = reference,
        reference_name = reference.name,
        pb_conda_image = pb_conda_image
    }
  }

  output {
  }
}
