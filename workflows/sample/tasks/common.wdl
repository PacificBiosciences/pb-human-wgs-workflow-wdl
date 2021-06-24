version 1.0

#import "../../common/structs.wdl"

import "https://raw.githubusercontent.com/bemosk/pb-human-wgs-workflow-wdl/bemosk-latest/workflows/common/structs.wdl"

task bgzip_vcf {
  input {
    Int threads = 2
    String bgzip_log_name = "bgzip.log"
    String tabix_log_name = "tabix.log"
    String params = "-p vcf"
    File vcf_input
    String vcf_gz_output_name = "~{basename(vcf_input)}.gz"

    String pb_conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(vcf_input, "GB")) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

    (bgzip --threads ~{threads} ~{vcf_input} -c > ~{vcf_gz_output_name}) > ~{bgzip_log_name} 2>&1
    (tabix ~{params} ~{vcf_gz_output_name}) > ~{tabix_log_name} 2>&1
  >>>
  output {
    File vcf_gz_data = "~{vcf_gz_output_name}"
    File vcf_gz_index = "~{vcf_gz_output_name}.tbi"
    IndexedData vcf_gz_output = { "datafile": vcf_gz_data, "indexfile": vcf_gz_index }

    File bgzip_log = "~{bgzip_log_name}"
    File tabix_log_name = "~{tabix_log_name}"
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

workflow common {
  input {
    File vcf_input
    String pb_conda_image
  }

  call bgzip_vcf {
    input:
      vcf_input = vcf_input,
      pb_conda_image = pb_conda_image
  }

  output {
    IndexedData vcf_gz = bgzip_vcf.vcf_gz_output
  }

}

