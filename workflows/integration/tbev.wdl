version 1.0

#import ./hifiasm/triobev.wdl

import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/hifiasm/triobev.wdl"

struct YakInfo {
  String name
  File fasta
}

workflow tbev {
  input {
    String cohort_name
    Array[YakInfo] yak_output
    File hap1_fasta_gz
    File hap2_fasta_gz
    Boolean triobin = true
    Boolean trioeval = false
    String pb_conda_image
  }

  call triobev.triobev {
    input:
     yak_parent1 = (yak_output[0].name, yak_output[0].fasta),
     yak_parent2 = (yak_output[1].name, yak_output[1].fasta),
     fasta_hap1_p_ctg_gz = hap1_fasta_gz,
     fasta_hap2_p_ctg_gz = hap2_fasta_gz,
     pb_conda_image = pb_conda_image,
     triobin = triobin,
     trioeval = trioeval
  }

  output {
  }
}
