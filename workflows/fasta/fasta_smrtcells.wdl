version 1.0

# The new workflow, fasta_conversion.wdl, is called here

import "../common/structs.wdl"
import "tasks/fasta_conversion.wdl" as fasta_conversion


workflow fasta_smrtcells {
  input {
    SmrtcellInfo smrtcell_info
    String pb_conda_image
  }

  call fasta_conversion.fasta_conversion  {
    input:
      movie = smrtcell_info,
      pb_conda_image = pb_conda_image
  }

  output {
    File movie_fasta = fasta_conversion.movie_fasta
  }
}
