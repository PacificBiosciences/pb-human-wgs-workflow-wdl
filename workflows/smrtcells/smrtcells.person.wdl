version 1.0

# A simplified data structure, Array[SampleInfo], is used here, and unffacted/affected lines are all removed by Charlie Bi
# Whenever affected/unaffected appears, it is removed and rewritten with one line of new code
#
# fasta_conversion's ourtput is returned here

import "./smrtcells.wdl" as smrtcells
import "../common/structs.wdl"


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
    Array[String] parents_names = sample.parents
    Pair[String, Array[File]] sample_fasta = (sample.name, smrtcells.movie_fasta)
  }
}

