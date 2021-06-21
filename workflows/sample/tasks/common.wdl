version 1.0

import "../structs/BamPair.wdl"

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

  command <<<
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
    disk: "200 GB"
  }
}

task tabix_vcf {
  input {
    String params = "-p vcf"
    String log_name = "tabix_vcf.log"
    File vcf_gz_input
    String vcf_gz_tbi_orig = "~{vcf_gz_input}.tbi"
    String vcf_gz_output_name = "~{basename(vcf_gz_input)}.tbi"

    Int threads = 4
    String pb_conda_image
  }

  command <<<
    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

    (tabix ~{params} ~{vcf_gz_input}) > ~{log_name} 2>&1
    mv ~{vcf_gz_tbi_orig} ~{vcf_gz_output_name}
  >>>
  output {
    File vcf_gz_tbi_output = "~{vcf_gz_output_name}"
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

workflow common {
  input {
    File vcf_input
#    Array[BamPair] bam_pairs
    String pb_conda_image
  }

  call bgzip_vcf {
    input:
      vcf_input = vcf_input,
      pb_conda_image = pb_conda_image
  }

#  call tabix_vcf {
#    input:
#      vcf_gz_input = bgzip_vcf.vcf_gz_output,
#      pb_conda_image = pb_conda_image
#  }

#  call samtools_index_bam {
#    input:
#      bam_pairs = bam_pairs,
#      pb_conda_image = pb_conda_image
#  }

  output {
#    File samtools_index_bam_outfile = samtools_index_bam.outfile1

    IndexedData vcf_gz = bgzip_vcf.vcf_gz_output
#    File bai_file = samtools_index_bam.bai_file
  }

}

