version 1.0

#import "./common_bgzip_vcf.wdl" as bgzip_vcf
#import "./pbsv_gather_svsigs.wdl"
#import "../../common/structs.wdl"
#import "../../common/separate_data_and_index_files.wdl"

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/cohort/tasks/common_bgzip_vcf.wdl" as bgzip_vcf
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

task pbsv_call {
  input {
    Int threads = 8
    Int memory_GB = 64
    String extra = "--ccs -m 20 -A 3 -O 3"
    String loglevel = "INFO"

    String log_name = "pbsv_call.log"

    Array[File] cohort_affected_person_svsigs
    Array[File] cohort_unaffected_person_svsigs
    IndexedData reference
    String cohort_name

    String pbsv_vcf_name = "~{cohort_name}.~{reference.name}.pbsv.vcf"
    String pb_conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(reference.datafile, "GB") + size(reference.indexfile, "GB") + size(cohort_affected_person_svsigs, "GB") + size(cohort_unaffected_person_svsigs, "GB"))) + 20
#  Int disk_size = 200

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate pbsv
    echo "$(conda info)"

    (
      pbsv call ~{extra} \
        --log-level ~{loglevel} \
        --num-threads ~{threads} \
        ~{reference.datafile} ~{sep=" " cohort_affected_person_svsigs}  ~{sep=" " cohort_unaffected_person_svsigs} ~{pbsv_vcf_name}
    ) > ~{log_name} 2>&1

  >>>
  output {
    File log = "~{log_name}"
    File pbsv_vcf = "~{pbsv_vcf_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "~{memory_GB} GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}

workflow pbsv {
  input {
    Array[Array[Array[File]]] affected_person_svsigs
    Array[Array[Array[File]]] unaffected_person_svsigs
    IndexedData reference
    String cohort_name
    String pb_conda_image
  }

  Array[File] flattened_affected_person_svsigs =   flatten(flatten(affected_person_svsigs))
  Array[File] flattened_unaffected_person_svsigs = flatten(flatten(unaffected_person_svsigs))

  call pbsv_call {
    input:
      cohort_name = cohort_name,
      cohort_affected_person_svsigs = flattened_affected_person_svsigs,
      cohort_unaffected_person_svsigs = flattened_unaffected_person_svsigs,
      reference = reference,
      pb_conda_image = pb_conda_image
    }

  call bgzip_vcf.bgzip_vcf {
      input :
        vcf_input = pbsv_call.pbsv_vcf,
        pb_conda_image = pb_conda_image
    }

  output {
    IndexedData pbsv_vcf = bgzip_vcf.vcf_gz_output
  }
}
