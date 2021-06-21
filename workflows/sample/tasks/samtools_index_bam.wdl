version 1.0

import "../structs/BamPair.wdl"

task samtools_index_bam {
  input {
    File bam_input
    Int threads = 4
    String log_name = "samtools_index_bam.log"
    String pb_conda_image
    String bam_input_name = "~{basename(bam_input)}"
  }

  command <<<
    source ~/.bashrc
    conda activate samtools
    echo "$(conda info)"

    cp ~{bam_input} ~{bam_input_name}
    (samtools index -@ 3 ~{bam_input_name}) > ~{log_name} 2>&1
  >>>
  output {
    File bam_data = "~{bam_input_name}"
    File bam_index = "~{bam_input_name}.bai"
    IndexedData bam_pair = { "datafile": bam_data, "indexfile": bam_index }

    File log = "~{log_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}
