version 1.0

#import "../../common/structs.wdl"

import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

task samtools_index_bam {
  input {
    File bam_datafile
    Int threads = 4
    String log_name = "samtools_index_bam.log"
    String pb_conda_image
    String bam_datafile_name = "~{basename(bam_datafile)}"
  }

  command <<<
    source ~/.bashrc
    conda activate samtools
    echo "$(conda info)"

    ln -s ~{bam_datafile} ~{bam_datafile_name} #note -- use ln -s to replace 'cp'
    (samtools index -@ 3 ~{bam_datafile_name}) > ~{log_name} 2>&1
  >>>
  output {
    IndexedData bam = { "datafile":  "~{bam_datafile_name}", "indexfile": "~{bam_datafile_name}.bai" }

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
