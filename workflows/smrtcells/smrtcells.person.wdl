version 1.0

import "./smrtcells.wdl" as smrtcells
import "../common/structs.wdl"

workflow smrtcells_person {
  input {
    IndexedData reference
    SampleInfo sample
    Int kmer_length

    String pb_conda_image
  }

  scatter(smrtcell_info in sample.smrtcells) {
    call smrtcells.smrtcells as smrtcells {
      input :
        reference = reference,
        sample_name = sample.name,
        smrtcell_info = smrtcell_info,
        kmer_length = kmer_length,

        pb_conda_image = pb_conda_image
    }
  }

  output {
    Array[IndexedData] bams     = smrtcells.bam
    Array[File] jellyfish_count = smrtcells.count_jf
  }
}
