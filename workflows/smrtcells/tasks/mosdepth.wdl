version 1.0

import "../structs/BamPair.wdl"

task mosdepth {
  input {
    IndexedData bam_pair
    String smrtcell_name
    String reference_name

    String prefix = "~{smrtcell_name}.~{reference_name}"

    String by = "500"
    String extra = "--no-per-base --use-median"
    Int threads = 4
    String log_name = "mosdepth.log"

    String pb_conda_image
  }

  command <<<
    source ~/.bashrc
    conda activate mosdepth
    echo "$(conda info)"

    (mosdepth \
      --threads ~{threads} --by ~{by} \
      ~{extra} ~{prefix} ~{bam_pair.datafile}
    ) > ~{log_name} 2>&1
  >>>
  output {
    File global = "~{prefix}.mosdepth.global.dist.txt"
    File region = "~{prefix}.mosdepth.region.dist.txt"
    File summary = "~{prefix}.mosdepth.summary.txt"
    File regions = "~{prefix}.regions.bed.gz"
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
