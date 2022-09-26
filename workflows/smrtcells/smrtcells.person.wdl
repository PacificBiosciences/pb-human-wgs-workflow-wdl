version 1.0

#import "./smrtcells.wdl" as smrtcells
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/smrtcells/smrtcells.wdl" as smrtcells
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

workflow smrtcells_person {
  input {
    IndexedData reference
    SampleInfo sample
    Int kmer_length

    String pb_conda_image
    Boolean run_jellyfish
  }

  scatter(smrtcell_info in sample.smrtcells) {
    call smrtcells.smrtcells as smrtcells {
      input :
        reference = reference,
        sample_name = sample.name,
        smrtcell_info = smrtcell_info,
        kmer_length = kmer_length,

        pb_conda_image = pb_conda_image,
        run_jellyfish = run_jellyfish
    }
  }

  output {
    Array[IndexedData] bams     = smrtcells.bam
    Array[File?] jellyfish_count = smrtcells.count_jf
    String sample_names  = sample.name
    Array[File?] movie_modimers = smrtcells.movie_modimers
    String sample_names  = sample.name
    Array[String?] parents_names = sample.parents
  }
}
