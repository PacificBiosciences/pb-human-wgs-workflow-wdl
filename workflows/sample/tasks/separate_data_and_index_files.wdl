version 1.0

import "../structs/BamPair.wdl"

task separate_data_and_index_files_single {
  input {
    IndexedData indexed_data
  }

  command <<<
  >>>
  output {
    File datafile = indexed_data.datafile
    File indexfile = indexed_data.indexfile
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

workflow separate_data_and_index_files {
  input {
    Array[IndexedData] indexed_data_array
  }

  scatter (indexed_data in indexed_data_array) {
    call separate_data_and_index_files_single {
      input:
        indexed_data = indexed_data
    }
  }

  output {
    Array[File] datafiles = separate_data_and_index_files_single.datafile
    Array[File] indexfiles = separate_data_and_index_files_single.indexfile
  }

}