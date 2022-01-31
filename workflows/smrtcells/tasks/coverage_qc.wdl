version 1.1

#import "../../common/structs.wdl"

import "https://raw.githubusercontent.com/ducatiMonster916/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

task infer_sex_from_coverage {
  input {
    SmrtcellInfo smrtcell_info
    String? reference_name
    File mosdepth_summary
    String inferred_sex_file_name = "~{smrtcell_info.name}.~{reference_name}.mosdepth.inferred_sex.txt"
    String log_name = "infer_sex_from_coverage.log"
    String pb_conda_image
    Int threads = 4
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(smrtcell_info.path, "GB") + size(mosdepth_summary, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate pandas
    echo "$(conda info)"

    (python3 /opt/pb/scripts/infer_sex_from_coverage.py ~{mosdepth_summary} > ~{inferred_sex_file_name}) > ~{log_name} 2>&1
  >>>
  output {
    File inferred_sex_file = "~{inferred_sex_file_name}"
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

task calculate_m2_ratio {
  input {
    SmrtcellInfo smrtcell_info
    String? reference_name
    File mosdepth_summary

    String log_name = "calculate_M2_ratio.log"
    String mosdepth_M2_ratio_name = "~{smrtcell_info.name}.~{reference_name}.mosdepth.M2_ratio.txt"
    String pb_conda_image
    Int threads = 4
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(smrtcell_info.path, "GB") + size(mosdepth_summary, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate pandas
    echo "$(conda info)"

    (python3 /opt/pb/scripts/calculate_M2_ratio.py ~{mosdepth_summary} > ~{mosdepth_M2_ratio_name}) > ~{log_name} 2>&1
  >>>
  output {
    File mosdepth_M2_ratio = "~{mosdepth_M2_ratio_name}"
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

workflow coverage_qc {
  input {
    SmrtcellInfo smrtcell_info
    String? reference_name
    File mosdepth_summary
    String pb_conda_image
  }

  call infer_sex_from_coverage {
    input:
      smrtcell_info = smrtcell_info,
      reference_name = reference_name,
      mosdepth_summary = mosdepth_summary,
      pb_conda_image = pb_conda_image
  }

  call calculate_m2_ratio {
    input:
      smrtcell_info = smrtcell_info,
      reference_name = reference_name,
      mosdepth_summary = mosdepth_summary,
      pb_conda_image = pb_conda_image
  }

  output {
    File inferred_sex_file = infer_sex_from_coverage.inferred_sex_file
    File mosdepth_M2_ratio = calculate_m2_ratio.mosdepth_M2_ratio
  }
}
