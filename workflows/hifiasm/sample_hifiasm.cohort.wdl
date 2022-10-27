version 1.0

#import "../common/structs.wdl"
#import "./tasks/hifiasm.wdl"


import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/hifiasm/tasks/hifiasm.wdl" as hifiasm

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
