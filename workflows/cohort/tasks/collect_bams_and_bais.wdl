version 1.0

import "../structs/BamPair.wdl"
import "./separate_data_and_index_files.wdl"

task gather_bam_pairs {
  input {
    SampleOutput sample_output
  }
  command <<<
  >>>
  output {
      Array[IndexedData] bam_pairs = sample_output.bam_pairs
  }
  runtime {
    docker: 'ubuntu:18.04'
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "3"
    disk: "200 GB"
  }
}

workflow collect_bams_and_bais {
  input {
    Array[SampleOutput] sample_outputs
  }

  scatter (sample_output in sample_outputs) {
    call gather_bam_pairs {
      input:
        sample_output = sample_output
    }
  }

  call separate_data_and_index_files.separate_data_and_index_files {
    input:
      indexed_data_array = flatten(gather_bam_pairs.bam_pairs)
  }

  output {
    Array[File] bams = separate_data_and_index_files.datafiles
    Array[File] bais = separate_data_and_index_files.indexfiles
  }

}