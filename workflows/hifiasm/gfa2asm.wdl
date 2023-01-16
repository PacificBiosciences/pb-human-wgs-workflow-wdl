version 1.0

import "../common/structs.wdl"
import "tasks/gfa2stats.wdl" as gfa2stats

workflow gfa2asm {
  input {
    File gfa
    IndexedData reference
    String pb_conda_image
  }

  call gfa2stats.gfa2stats {
   input:
     gfa = gfa,
     index = reference.indexfile,
     pb_conda_image = pb_conda_image
  }

  output {
  }
}

