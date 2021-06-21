version 1.0

import "./smrtcells.wdl" as smrtcells
import "./structs/BamPair.wdl"

workflow smrtcells_person {
  input {
    String md5sum_name

    IndexedData reference
    String reference_name
    SampleInfo sample
    Int kmer_length

    String pb_conda_image
  }

  scatter(smrtcell_info in sample.smrtcells) {
    call smrtcells.smrtcells as smrtcells {
      input :
        md5sum_name = md5sum_name,

        reference = reference,
        reference_name = reference_name,
        sample_name = sample.name,
        smrtcell_info = smrtcell_info,
        kmer_length = kmer_length,

        pb_conda_image = pb_conda_image
    }
  }

  output {
    Array[IndexedData] bam_pairs = smrtcells.bam_pair
    Array[File] jellyfish_count = smrtcells.count_jf
  }
}
