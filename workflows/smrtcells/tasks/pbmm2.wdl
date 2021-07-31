version 1.0

#import "../../common/structs.wdl"

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/dev/workflows/common/structs.wdl"

task align_ubam_or_fastq {
  input {
    IndexedData reference

    String sample_name
    SmrtcellInfo smrtcell_info

    String preset = "CCS"
    String extra = "--sort --unmapped -c 0 -y 70"
    String loglevel = "INFO"
    String sample = "--rg '@RG\tID:~{sample_name}\tSM:~{sample_name}'"

    String pbmm2_index_log_name = "pbmm2_index.log"
    String pbmm2_align_log_name = "pbmm2_align.log"
    String ref_index_mmi_name = "ref.index.mmi"

    String bam_name = "~{smrtcell_info.name}.~{reference.name}.bam"

    Int threads = 24
    String pb_conda_image
  }

#  Float multiplier = 3.25
#  Int disk_size = ceil(multiplier * (size(reference.datafile, "GB") + size(reference.indexfile, "GB") + size(smrtcell_info.path, "GB"))) + 20
  Int disk_size = 200

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate pbmm2
    echo "$(conda info)"

    ( 
        pbmm2 index ~{reference.datafile} ~{ref_index_mmi_name} 
    ) > ~{pbmm2_index_log_name} 2>&1
    (
        pbmm2 align --num-threads ~{threads} \
            --preset ~{preset} \
            --log-level ~{loglevel} \
            ~{extra} \
            ~{sample} \
            ~{ref_index_mmi_name} \
            ~{smrtcell_info.path} \
            ~{bam_name} \
    ) > ~{pbmm2_align_log_name} 2>&1

  >>>
  output {
    IndexedData bam = { "name": smrtcell_info.name, "datafile": "~{bam_name}", "indexfile": "~{bam_name}.bai" }

    File ref_index_mmi = "~{ref_index_mmi_name}"
    File pbmm2_index_log = "~{pbmm2_index_log_name}"
    File pbmm2_align_log = "~{pbmm2_align_log_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "256 GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}
