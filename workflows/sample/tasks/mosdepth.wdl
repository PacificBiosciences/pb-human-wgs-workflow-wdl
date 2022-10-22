version 1.0

#import "../../common/structs.wdl"

import "https://raw.githubusercontent.com/vsmalladi/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

task mosdepth {
  input {
    Int threads = 4
    String by = "500"
    String extra = "--no-per-base --use-median"

    String sample_name
    String? reference_name
    String prefix = "~{sample_name}.~{reference_name}"

    String log_name = "mosdepth.log"
    IndexedData bam

    String pb_conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(bam.datafile, "GB") + size(bam.indexfile, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate mosdepth
    echo "$(conda info)"

    (mosdepth --threads ~{threads} --by ~{by} \
        ~{extra} ~{prefix} ~{bam.datafile}) > ~{log_name} 2>&1
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
    disk: disk_size + " GB"
  }
}
