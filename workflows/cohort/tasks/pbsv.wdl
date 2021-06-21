version 1.0

import "./common_bgzip_vcf.wdl" as bgzip_vcf
import "./pbsv_gather_svsigs.wdl"
import "../structs/BamPair.wdl"
import "./separate_data_and_index_files.wdl"

task pbsv_call {
  input {
    Int threads = 8
    String extra = "--ccs -m 20 -A 3 -O 3 -P 20"
    String loglevel = "INFO"

    String log_name = "pbsv_call.log"

    Array[File] cohort_affected_patient_svsigs
    Array[File] cohort_unaffected_patient_svsigs
    IndexedData reference 
    String cohort_name
    String region

    String pbsv_vcf_name = "~{cohort_name}.~{reference.name}.~{region}.pbsv.vcf"
    String pb_conda_image
  }

  command <<<
    source ~/.bashrc
    conda activate pbsv
    echo "$(conda info)"

    (
      pbsv call ~{extra} \
        --log-level ~{loglevel} \
        --num-threads ~{threads} \
        ~{reference.datafile} ~{sep=" " cohort_affected_patient_svsigs}  ~{sep=" " cohort_unaffected_patient_svsigs} ~{pbsv_vcf_name}
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
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

task bcftools_concat_pbsv_vcf {
  input {
    String log_name = "bcftools_concat_pbsv_vcf.log"
    Array[File] calls
    Array[File] indices

    String cohort_name
    String? reference_name
    String pbsv_vcf_name = "~{cohort_name}.~{reference_name}.pbsv.vcf"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate bcftools
    echo "$(conda info)"

    (bcftools concat -a -o ~{pbsv_vcf_name} ~{sep=" " calls}) > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    File pbsv_vcf = "~{pbsv_vcf_name}"
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

workflow pbsv {
  input {
    Array[Array[Array[File]]] affected_patient_svsigs
    Array[Array[Array[File]]] unaffected_patient_svsigs
    IndexedData reference
    Array[String] regions
    String cohort_name
    String pb_conda_image
  }

  scatter(region_num in range(length(regions))) {
    call pbsv_gather_svsigs.gather_svsigs_by_region as gather_affected_patient_svsigs {
      input:
        sample_svsigs = affected_patient_svsigs,
        region_num = region_num
    }
  }

  scatter(region_num in range(length(regions))) {
    call pbsv_gather_svsigs.gather_svsigs_by_region as gather_unaffected_patient_svsigs {
      input:
        sample_svsigs = unaffected_patient_svsigs,
        region_num = region_num
    }
  }

  scatter(region_num in range(length(regions))) {
    call pbsv_call {
      input:
        cohort_name = cohort_name,
        region = regions[region_num],
        cohort_affected_patient_svsigs = if defined(gather_affected_patient_svsigs.svsigs) then gather_affected_patient_svsigs.svsigs[region_num] else [],
        cohort_unaffected_patient_svsigs = if defined(gather_unaffected_patient_svsigs.svsigs) then gather_unaffected_patient_svsigs.svsigs[region_num] else [],
        reference = reference,
        pb_conda_image = pb_conda_image
    }
  }

  scatter(call_pbsv_vcf in pbsv_call.pbsv_vcf) {
    call bgzip_vcf.bgzip_vcf {
      input :
        vcf_input = call_pbsv_vcf,
        pb_conda_image = pb_conda_image
    }
  }

  call separate_data_and_index_files.separate_data_and_index_files {
    input:
      indexed_data_array = bgzip_vcf.vcf_gz_output
  }

  call bcftools_concat_pbsv_vcf {
   input:
      cohort_name = cohort_name,
      reference_name = reference.name,
      calls = separate_data_and_index_files.datafiles,
      indices = separate_data_and_index_files.indexfiles,
      pb_conda_image = pb_conda_image
  }

  output {
  }

}

