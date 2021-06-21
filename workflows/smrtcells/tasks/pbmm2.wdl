version 1.0

import "../structs/BamPair.wdl"

task align_ubam_or_fastq {
  input {
    IndexedData reference
    String reference_name

    String sample_name
    SmrtcellInfo smrtcell_info

    String preset = "CCS"
    String extra = "--sort --unmapped -c 0 -y 70"
    String loglevel = "INFO"

    String pbmm2_index_log_name = "pbmm2_index.log"

    String bam_name = "~{smrtcell_info.name}.~{reference_name}.bam"

    Int threads = 24
    String pb_conda_image
  }

  command <<<

    source ~/.bashrc
    conda activate pbmm2
    echo "$(conda info)"

    (pbmm2 align --num-threads ~{threads} \
      --preset ~{preset} \
      --log-level ~{loglevel} \
      --sample ~{sample_name} \
      ~{extra} \
      ~{reference.datafile} \
      ~{smrtcell_info.path} \
      ~{bam_name} \
    ) > ~{pbmm2_align_log_name} 2>&1

  >>>
  output {
    File bam_datafile = "~{bam_name}"
    File bam_indexfile = "~{bam_name}.bai"
    IndexedData bam_pair = { "datafile": bam_datafile, "indexfile": bam_indexfile }

    File pbmm2_align_log = "~{pbmm2_align_log_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "256 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}
