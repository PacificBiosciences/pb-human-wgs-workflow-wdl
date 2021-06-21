version 1.0

import "../structs/BamPair.wdl"

task gather_svsigs_by_sample_and_region {
  input {
    Array[Array[File]] svsigs_by_regions
    Int region_num
  }
  command <<<
  >>>
  output {
      Array[File] svsigs = svsigs_by_regions[region_num]
  }
  runtime {
    docker: 'ubuntu:18.04'
    preemptible: true
  }
}

workflow gather_svsigs_by_region {
  input {
    Array[Array[Array[File]]] sample_svsigs
    Int region_num
  }

  scatter (svsigs_by_regions in sample_svsigs) {
    call gather_svsigs_by_sample_and_region {
      input:
        svsigs_by_regions = svsigs_by_regions,
        region_num = region_num
    }
  }

  output {
    Array[File] svsigs = flatten(gather_svsigs_by_sample_and_region.svsigs)
  }
}