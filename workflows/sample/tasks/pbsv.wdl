version 1.0

import "../structs/BamPair.wdl"
import "./pbsv_discover.wdl" as pbsv_discover
import "./common.wdl" as common
import "./separate_data_and_index_files.wdl"

task pbsv_call {
  input {
    Int threads = 8
    String region 
    String extra = "--ccs -m 20 -A 3 -O 3"
    String loglevel = "INFO"
    String log_name = "pbsv_call.log"
    Array[File] svsigs
    IndexedData reference
    String sample_name

    String pbsv_vcf_name = "~{sample_name}.~{reference.name}.~{region}.pbsv.vcf"
    String pb_conda_image
  }

  command <<<
    source ~/.bashrc
    conda activate pbsv
    echo "$(conda info)"

    (pbsv call ~{extra} \
      --log-level ~{loglevel} \
      --num-threads ~{threads} \
      ~{reference.datafile} ~{sep=" " svsigs} ~{pbsv_vcf_name}) > ~{log_name} 2>&1
  >>>
  output {
    File pbsv_vcf = "~{pbsv_vcf_name}"
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

task bcftools_concat_pbsv_vcf {
  input {
    String log_name = "bcftools_concat.pbsv.vcf.log"
    String sample_name
    String? reference_name
    String pbsv_vcf_name = "~{sample_name}.~{reference_name}.pbsv.vcf"
    Array[File] calls
    Array[File] indices
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
    File pbsv_vcf = "~{pbsv_vcf_name}"
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

workflow pbsv {
  input {
    Array[String] regions
    SampleInfo sample
    File tr_bed
    IndexedData reference

    String pb_conda_image
  }

  scatter(region in regions) {
    call pbsv_discover.pbsv_discover_by_smartcells_output {
      input:
        region = region,
        sample = sample,
        reference_name = reference.name,
        tr_bed = tr_bed,
        pb_conda_image = pb_conda_image
    }
  }

  scatter(region_num in range(length(regions))) {
    call pbsv_call {
      input:
        region = regions[region_num],
        svsigs = pbsv_discover_by_smartcells_output.discover_svsig_gv[region_num],
        reference = reference,
        sample_name = sample.name,
        pb_conda_image = pb_conda_image
    }
  }

  scatter(call_pbsv_vcf in pbsv_call.pbsv_vcf) {
    call common.common {
      input :
        vcf_input = call_pbsv_vcf,
        pb_conda_image = pb_conda_image
    }
  }

  call separate_data_and_index_files.separate_data_and_index_files {
    input:
      indexed_data_array = common.vcf_gz,
  }

  call bcftools_concat_pbsv_vcf {
   input:
      sample_name = sample.name,
      reference_name = reference.name,
      calls = separate_data_and_index_files.datafiles,
      indices = separate_data_and_index_files.indexfiles,
      pb_conda_image = pb_conda_image
  }

  output {
    Array[Array[File]] svsig_gv = pbsv_discover_by_smartcells_output.discover_svsig_gv
  }

}
